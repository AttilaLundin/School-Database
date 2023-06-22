import java.sql.*; // JDBC stuff.
import java.util.Properties;
import java.util.Scanner;

public class PortalConnection {

    // Set this to e.g. "portal" if you have created a database named portal
    // Leave it blank to use the default database of your database user
    static final String DBNAME = "newdbforpractice";
    // For connecting to the portal database on your local machine
    static final String DATABASE = "jdbc:postgresql://localhost/"+DBNAME;
    static final String USERNAME = "guest";
    static final String PASSWORD = "guest";

    // For connecting to the chalmers database server (from inside chalmers)
    // static final String DATABASE = "jdbc:postgresql://brage.ita.chalmers.se/";
    // static final String USERNAME = "tda357_nnn";
    // static final String PASSWORD = "yourPasswordGoesHere";


    // This is the JDBC connection object you will be using in your methods.
    private Connection conn;

    public PortalConnection() throws SQLException, ClassNotFoundException {
        this(DATABASE, USERNAME, PASSWORD);  
    }

    // Initializes the connection, no need to change anything here
    public PortalConnection(String db, String user, String pwd) throws SQLException, ClassNotFoundException {
        Class.forName("org.postgresql.Driver");
        Properties props = new Properties();
        props.setProperty("user", user);
        props.setProperty("password", pwd);
        conn = DriverManager.getConnection(db, props);
    }


    // Register a student on a course, returns a tiny JSON document (as a String)
    public String register(String student, String courseCode){

        try(PreparedStatement ps = conn.prepareStatement("INSERT INTO registrations VALUES (?, ?)");){
            ps.setString(1, student);
            ps.setString(2, courseCode);
            int r = ps.executeUpdate();
            System.out.println("Rows affected;" + r);
            return "{\"success\":true, student:" + student + " is now registered" + " on \"Course: " + courseCode + "\"}";
        }catch (SQLException e){
            return "{\"success\":false, \"error\":\""+getError(e)+"\"}";
        }
    }

    // safe option using prepared statements with setstring
    // Unregister a student from a course, returns a tiny JSON document (as a String)
    public String unregister(String student, String courseCode){
        try(PreparedStatement ps = conn.prepareStatement("DELETE FROM Registrations WHERE student = ? AND course = ?");){
            ps.setString(1, student);
            ps.setString(2, courseCode);
            int r = ps.executeUpdate();

            if(r == 0) throw new SQLException("Student: " + student + " is not registered and can thus not be removed");

            return "{\"success\":true, student:" + student + " is now unregistered from " + " Course: " + courseCode + "}";

        }catch (SQLException e){
            return "{\"success\":false, \"error\":\""+getError(e)+"\"}";
        }
    }

        // Return a JSON document containing lots of information about a student, it should validate against the schema found in information_schema.json
    public String getInfo(String student) throws SQLException{

        try(PreparedStatement st = conn.prepareStatement(
            "SELECT json_build_object(\n" +
                    "    'student', idnr,\n" +
                    "    'name', name,\n" +
                    "    'login', login,\n" +
                    "    'program', program,\n" +
                    "    'branch', branch,\n" +
                    "    'finished', (SELECT COALESCE(json_agg(json_build_object(\n" +
                    "        'course', (SELECT name FROM courses WHERE code = course),\n" +
                    "        'code', course,\n" +
                    "        'credits', credits,\n" +
                    "        'grade', grade\n" +
                    "    )), '[]') FROM finishedcourses WHERE student = idnr),\n" +
                    "\n" +
                    "    'registered', (SELECT COALESCE(json_agg(json_build_object(\n" +
                    "        'course',(SELECT name FROM courses where code = course),\n" +
                    "        'code', course,\n" +
                    "        'status', status,\n" +
                    "        'position',(SELECT position FROM waitinglist AS wl WHERE wl.course = reg.course AND wl.student = reg.student)\n" +
                    "    )), '[]') FROM registrations AS reg WHERE student = idnr),\n" +
                    "\n" +
                    "    'seminarCourses', seminarcourses,\n" +
                    "    'mathCourses', mathcredits,\n" +
                    "    'researchCredits', researchcredits,\n" +
                    "    'totalCredits', totalcredits,\n" +
                    "    'canGraduate', qualified\n" +
                    "    )AS jsondata FROM basicinformation JOIN pathtograduation ON student = idnr WHERE idnr = ?;"
            );){

            st.setString(1, student);
            ResultSet rs = st.executeQuery();

            if(rs.next())
              return rs.getString("jsondata");
            else
              return "{\"student\":\"does not exist :(\"}";

        }
    }

    // This is a hack to turn an SQLException into a JSON string error message. No need to change.
    public static String getError(SQLException e){
        String message = e.getMessage();
        int ix = message.indexOf('\n');
        if (ix > 0) message = message.substring(0, ix);
        message = message.replace("\"","\\\"");
        return message;
    }

    /*

    //UNSAFE CODE! Does not use the setString funtion
    //Easily brakeable, first insert idnr to get the idnr for the first student in the table, returns all but only the first is displayed
    //if you want to drop all registrations you incert student then course.
    // alt an expression within '(here)' followed by an or and then a statement that evaluates to true
    // EX: Karins Lasagne' or 'stinas kyckling' = 'stinas kyckling


    public String unregister(String student, String courseCode) {
        try (PreparedStatement ps = conn.prepareStatement("DELETE FROM Registrations WHERE student = '" +  student  + "' AND course = '" + courseCode + "';" );) {
            int r = ps.executeUpdate();
            System.out.println("Rows affected;" + r);
            if(r == 0) throw new SQLException("Student: " + student + " is not registered and can thus not be removed");
            return "{\"success\":true, student:" + student + " is now unregistered from " + " Course: " + courseCode + "}";

        } catch (SQLException e) {
            return "{\"success\":false, \"error\":\"" + getError(e) + "\"}";
        }
    }
    // Return a JSON document containing lots of information about a student, it should validate against the schema found in information_schema.json
    public String getInfo(String student) throws SQLException{

        try(PreparedStatement st = conn.prepareStatement(
                // replace this with something more useful
                "SELECT json_build_object(\n" +
                        "    'student', idnr,\n" +
                        "    'name', name,\n" +
                        "    'login', login,\n" +
                        "    'program', program,\n" +
                        "    'branch', branch,\n" +
                        "    'finished', (SELECT COALESCE(json_agg(json_build_object(\n" +
                        "        'course', (SELECT name FROM courses WHERE code = course),\n" +
                        "        'code', course,\n" +
                        "        'credits', credits,\n" +
                        "        'grade', grade\n" +
                        "    )), '[]') FROM finishedcourses WHERE student = idnr),\n" +
                        "\n" +
                        "    'registered', (SELECT COALESCE(json_agg(json_build_object(\n" +
                        "        'course',(SELECT name FROM courses where code = course),\n" +
                        "        'code', course,\n" +
                        "        'status', status,\n" +
                        "        'position',(SELECT position FROM waitinglist AS wl WHERE wl.course = reg.course AND wl.student = reg.student)\n" +
                        "    )), '[]') FROM registrations AS reg WHERE student = idnr),\n" +
                        "\n" +
                        "    'seminarCourses', seminarcourses,\n" +
                        "    'mathCourses', mathcredits,\n" +
                        "    'researchCredits', researchcredits,\n" +
                        "    'totalCredits', totalcredits,\n" +
                        "    'canGraduate', qualified\n" +
                        "    )AS jsondata FROM basicinformation JOIN pathtograduation ON student = idnr WHERE idnr ='" +student +  "';"
        );){
           // System.out.println(st);
            ResultSet rs = st.executeQuery();

            if(rs.next())
                return rs.getString("jsondata");
            else
                return "{\"student\":\"does not exist :(\"}";

        }
    }

     */




}