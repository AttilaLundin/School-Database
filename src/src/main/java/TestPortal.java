public class TestPortal {

   // enable this to make pretty printing a bit more compact
   private static final boolean COMPACT_OBJECTS = false;

   // This class creates a portal connection and runs a few operation

   public static void main(String[] args) {
      try{
         PortalConnection c = new PortalConnection();

         // Write your tests here. Add/remove calls to pause() as desired. 
         // Use println instead of prettyPrint to get more compact output (if your raw JSON is already readable)

          System.out.println("Test 1: List info for a student 2222222222");
          prettyPrint(c.getInfo("2222222222"));
          pause();

          System.out.println("Test 2: Register on unlimited course, 'Student: 2222222222' and 'Course CCC111'");
          System.out.println(c.register("2222222222", "CCC111"));
          pause();
          prettyPrint(c.getInfo("2222222222"));
          pause();

          System.out.println("Test 3: register on course that is already registered to");
          System.out.println(c.register("2222222222", "CCC111"));
          pause();

          System.out.println("Test 4: Unregister the 'student:2222222222' from 'course: CCC111");
          System.out.println(c.unregister("2222222222", "CCC111"));
          pause();
          System.out.println("Test 4: Unregister the 'student:2222222222' from 'course: CCC111' when not registered");
          System.out.println(c.unregister("2222222222", "CCC111"));
          pause();

          System.out.println("Test 5: Register student:2222222222 for a course (CCC555) that they don't have the prerequisites for ");
          System.out.println(c.register("2222222222", "CCC555"));
          pause();

          System.out.println("Test 6: Unregister a student from a restricted course that they are registered to, \n" +
                  "and which has at least two students in the queue. \n" +
                  "Register again to the same course and check that the student gets\n" +
                  "the correct (last) position in the waiting list.");
          System.out.println(c.unregister("2222222222", "CCC222"));
          pause();
          System.out.println("Test 6: second part");
          System.out.println(c.register("2222222222", "CCC222"));
          pause();

          System.out.println("Test 7: Unregister and re-register the same student for the same restricted course, \n" +
                  "and check that the student is first removed and then ends up in the same position as before (last)");
          System.out.println(c.unregister("2222222222", "CCC222"));
          pause();
          System.out.println("Test 7: second part");
          System.out.println(c.register("2222222222", "CCC222"));
          pause();

          System.out.println("Test 8: Unregister a student from an overfull course, \n" +
                  "i.e. one with more students registered than there are places on the course (you need to set this situation up in the database directly)." +
                  "\nCheck that no student was moved from the queue to being registered as a result.");
          System.out.println(c.unregister("1111111111", "CCC333"));
          pause();

          System.out.println("Test 9: Unregister with the SQL injection you introduced, causing all (or almost all?) registrations to disappear.");
          System.out.println(c.unregister("x' OR '1' = '1", "x' OR '1'= '1"));





      } catch (ClassNotFoundException e) {
         System.err.println("ERROR!\nYou do not have the Postgres JDBC driver (e.g. postgresql-42.2.18.jar) in your runtime classpath!");
      } catch (Exception e) {
         e.printStackTrace();
      }
   }
   
   
   
   public static void pause() throws Exception{
     System.out.println("PRESS ENTER");
     while(System.in.read() != '\n');
   }
   
   // This is a truly horrible and bug-riddled hack for printing JSON. 
   // It is used only to avoid relying on additional libraries.
   // If you are a student, please avert your eyes.
   public static void prettyPrint(String json){
      System.out.print("Raw JSON:");
      System.out.println(json);
      System.out.println("Pretty-printed (possibly broken):");
      
      int indent = 0;
      json = json.replaceAll("\\r?\\n", " ");
      json = json.replaceAll(" +", " "); // This might change JSON string values :(
      json = json.replaceAll(" *, *", ","); // So can this
      
      for(char c : json.toCharArray()){
        if (c == '}' || c == ']') {
          indent -= 2;
          breakline(indent); // This will break string values with } and ]
        }
        
        System.out.print(c);
        
        if (c == '[' || c == '{') {
          indent += 2;
          breakline(indent);
        } else if (c == ',' && !COMPACT_OBJECTS) 
           breakline(indent);
      }
      
      System.out.println();
   }
   
   public static void breakline(int indent){
     System.out.println();

     for(int i = 0; i < indent; i++)
       System.out.print(" ");
   }   
}