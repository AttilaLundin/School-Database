CREATE TABLE Programs(
    name         VARCHAR(60) PRIMARY KEY NOT NULL,
    abbriviation VARCHAR(10)             NOT NULL
);

CREATE TABLE Students(
    idnr    VARCHAR(10) NOT NULL PRIMARY KEY,
    name    VARCHAR(60) NOT NULL,
    login   VARCHAR(60) NOT NULL UNIQUE,
    program VARCHAR(6)  NOT NULL REFERENCES Programs (name),
    UNIQUE (idnr, program)
);

CREATE TABLE Branches(
    name    VARCHAR(60) NOT NULL,
    program VARCHAR(60) NOT NULL REFERENCES Programs (name),
    PRIMARY KEY (name, program)
);

CREATE TABLE Departments(
    name         VARCHAR(60) NOT NULL UNIQUE,
    abbriviation VARCHAR(10) NOT NULL PRIMARY KEY
);

CREATE TABLE HostDepartment(
    department VARCHAR(60) NOT NULL REFERENCES Departments (name),
    program    VARCHAR(60) NOT NULL REFERENCES Programs (name),
    PRIMARY KEY (department, program)
);

CREATE TABLE Courses(
    code       VARCHAR(6) NOT NULL PRIMARY KEY,
    name       VARCHAR(60) NOT NULL,
    credits    NUMERIC     NOT NULL
        CONSTRAINT credit_ok CHECK (credits > 0),
    department VARCHAR(60) NOT NULL REFERENCES Departments (name)
);

CREATE TABLE MandatoryBranch(
    course  VARCHAR(6) NOT NULL REFERENCES Courses (code),
    branch  VARCHAR(30) NOT NULL,
    program VARCHAR(40) NOT NULL,
    FOREIGN KEY (branch, program) REFERENCES Branches (name, program),
    PRIMARY KEY (course, branch, program)
);

CREATE TABLE RecommendedBranch(
    course  VARCHAR(6)  NOT NULL REFERENCES Courses (code),
    branch  VARCHAR(30) NOT NULL,
    program VARCHAR(40) NOT NULL,
    FOREIGN KEY (branch, program) REFERENCES Branches (name, program),
    PRIMARY KEY (course, branch, program)
);

CREATE TABLE MandatoryProgram(
    course  VARCHAR(6) NOT NULL REFERENCES courses (code),
    program VARCHAR(60) NOT NULL REFERENCES Programs (name),
    PRIMARY KEY (course, program)
);

CREATE TABLE StudentBranches(
    student     VARCHAR(10) NOT NULL PRIMARY KEY,
    branch      VARCHAR(30) NOT NULL,
    programName VARCHAR(40) NOT NULL,
    FOREIGN KEY (student, programName) REFERENCES Students (idnr, program),
    FOREIGN KEY (branch, programName) REFERENCES Branches (name, program)
);

CREATE TABLE Registered(
    student VARCHAR(10) NOT NULL REFERENCES Students (idnr),
    course  VARCHAR(6) NOT NULL REFERENCES Courses (code),
    PRIMARY KEY (student, course)
);

create table Taken(
    student VARCHAR(10) NOT NULL REFERENCES Students (idnr),
    course  VARCHAR(6)  NOT NULL REFERENCES Courses (code),
    grade   CHAR(1)     NOT NULL
        CONSTRAINT grade_ok CHECK (
            grade IN ('U', '3', '4', '5')
            ),
    PRIMARY KEY (student, course)
);

CREATE TABLE LimitedCourses(
    course   VARCHAR(6) NOT NULL PRIMARY KEY REFERENCES Courses (code),
    capacity INT         NOT NULL
        CONSTRAINT cap_ok CHECK ( capacity >= 0 and capacity < 150)
);

CREATE TABLE WaitingList(
    student  VARCHAR(10) NOT NULL REFERENCES Students (idnr),
    course   VARCHAR(6) NOT NULL REFERENCES LimitedCourses (course),
    position NUMERIC NOT NULL,
    UNIQUE (course, position),
    PRIMARY KEY (student, course)
);

create table Classifications(
    name VARCHAR(10) NOT NULL PRIMARY KEY
);

create table Classified(
    course         VARCHAR(6)  NOT NULL REFERENCES Courses (code),
    classification VARCHAR(10) NOT NULL REFERENCES Classifications (name),
    PRIMARY KEY (course, classification)
);

CREATE TABLE CoursesWithPreRequisite(
    courseWithPrerequisiteCourse VARCHAR(6) NOT NULL REFERENCES Courses (code),
    preRequisiteCourses          varchar(6) NOT NULL REFERENCES Courses (code),
    PRIMARY KEY (courseWithPrerequisiteCourse, preRequisiteCourses)
);

------------------------------------------------------------------------------------------------------------------------------------------------------------------

CREATE VIEW BasicInformation AS
SELECT students.idnr, students.name, students.login, students.program, studentbranches.branch
FROM students
LEFT JOIN studentbranches ON students.idnr = studentbranches.student;

CREATE VIEW FinishedCourses AS
SELECT t.student, t.course, t.grade, c.credits
FROM Taken t JOIN Courses c ON t.course = c.code;

CREATE VIEW PassedCourses AS
SELECT student, course, credits
FROM FinishedCourses
WHERE grade != 'U';

Create view Registrations AS
SELECT student, course, 'registered' AS Status
FROM registered
UNION
SELECT student, course, 'waiting' AS Status
FROM WaitingList
ORDER BY student, course;

CREATE VIEW UnreadMandatory AS
SELECT idnr AS student, course
FROM basicinformation AS bi
JOIN mandatorybranch mb on bi.program = mb.program AND bi.branch = mb.branch
UNION
SELECT idnr AS student, course
FROM basicinformation AS bi
JOIN MandatoryProgram mp on bi.program = mp.program
EXCEPT
SELECT student, course
FROM passedcourses;

CREATE VIEW TotalCredits_HW AS
SELECT student, SUM(credits) AS totalCredits
FROM passedcourses
GROUP BY student;

CREATE VIEW mandatoryLeft_HW AS
SELECT student, COUNT(course) AS mandatoryleft
FROM UnreadMandatory
GROUP BY student;

CREATE VIEW mathCredits_HW AS
SELECT student, SUM(credits) AS mathCredits
FROM PassedCourses AS pc
         JOIN classified AS cl ON pc.course = cl.course AND cl.classification = 'math'
GROUP BY student;

CREATE VIEW researchCredits_HW AS
SELECT student, SUM(credits) AS researchCredits
FROM PassedCourses AS pc
         JOIN classified AS cl ON pc.course = cl.course AND cl.classification = 'research'
GROUP BY student;

CREATE VIEW seminarCourses_HW AS
SELECT student, COUNT(credits) AS seminarCourses
FROM PassedCourses AS pc
         JOIN classified AS cl ON pc.course = cl.course AND cl.classification = 'seminar'
GROUP BY student;

CREATE VIEW recommended_credits_HW AS
SELECT idnr AS student, SUM(credits) AS recomendedCredits
FROM basicinformation AS bi
         JOIN PassedCourses AS pc ON pc.student = bi.idnr
         JOIN recommendedbranch AS rb ON pc.course = rb.course AND bi.program = rb.program AND bi.branch = rb.branch
GROUP BY idnr;

CREATE VIEW qualified_HW AS
    SELECT idnr AS student, rc.recomendedCredits >= 10 AND mc.mathcredits >= 20 AND rec.researchcredits >= 10 AND sc.seminarCourses >= 1 AS qualified
    FROM basicinformation AS bi
    JOIN recommended_credits_HW AS rc ON bi.idnr = rc.student
    JOIN mathCredits_HW AS mc ON bi.idnr = mc.student
    JOIN researchCredits_HW AS rec ON bi.idnr = rec.student
    JOIN seminarCourses_HW AS sc on bi.idnr = sc.student
    EXCEPT
    SELECT student, mandatoryleft > 0
    FROM mandatoryLeft_HW;

CREATE VIEW PathToGraduation AS
SELECT bi.idnr                      AS student,
       COALESCE(totalCredits, 0)    AS totalCredits,
       COALESCE(mandatoryLeft, 0)   AS mandatoryLeft,
       COALESCE(mathCredits, 0)     AS mathCredits,
       COALESCE(researchCredits, 0) AS researchCredits,
       COALESCE(seminarCourses, 0)  AS seminarCourses,
       COALESCE(qualified, false)   AS qualified
FROM BasicInformation AS bi
         LEFT JOIN TotalCredits_HW AS tc ON tc.student = bi.idnr
         LEFT JOIN mandatoryLeft_HW AS ml ON ml.student = bi.idnr
         LEFT JOIN mathCredits_HW AS mc ON mc.student = bi.idnr
         LEFT JOIN researchCredits_HW AS rc ON rc.student = bi.idnr
         LEFT JOIN seminarCourses_HW AS sc ON sc.student = bi.idnr
         LEFT JOIN qualified_HW AS qual ON qual.student = bi.idnr;

CREATE VIEW CourseQueuePositions AS
    SELECT course, student, position AS place FROM waitinglist;

------------------------------------------------------------------------------------------
INSERT INTO programs VALUES ('Prog1', 'P1');
INSERT INTO programs VALUES ('Prog2', 'P2');

INSERT INTO Students VALUES ('1111111111','N1','ls1','Prog1');
INSERT INTO Students VALUES ('2222222222','N2','ls2','Prog1');
INSERT INTO Students VALUES ('3333333333','N3','ls3','Prog2');
INSERT INTO Students VALUES ('4444444444','N4','ls4','Prog1');
INSERT INTO Students VALUES ('5555555555','Nx','ls5','Prog2');
INSERT INTO Students VALUES ('6666666666','Nx','ls6','Prog2');

INSERT INTO Branches VALUES ('B1','Prog1');
INSERT INTO Branches VALUES ('B2','Prog1');
INSERT INTO Branches VALUES ('B1','Prog2');

INSERT INTO Departments VALUES ('Dep1','D1');

INSERT INTO HostDepartment VALUES ('Dep1', 'Prog1');
INSERT INTO HostDepartment VALUES ('Dep1', 'Prog2');

INSERT INTO Courses VALUES ('CCC111','C1',22.5,'Dep1');
INSERT INTO Courses VALUES ('CCC222','C2',20,'Dep1');
INSERT INTO Courses VALUES ('CCC333','C3',30,'Dep1');
INSERT INTO Courses VALUES ('CCC444','C4',60,'Dep1');
INSERT INTO Courses VALUES ('CCC555','C5',50,'Dep1');

INSERT INTO MandatoryBranch VALUES ('CCC333', 'B1', 'Prog1');
INSERT INTO MandatoryBranch VALUES ('CCC444', 'B1', 'Prog2');

INSERT INTO RecommendedBranch VALUES ('CCC222', 'B1', 'Prog1');
INSERT INTO RecommendedBranch VALUES ('CCC333', 'B1', 'Prog2');

INSERT INTO MandatoryProgram VALUES ('CCC111','Prog1');

INSERT INTO StudentBranches VALUES ('2222222222','B1','Prog1');
INSERT INTO StudentBranches VALUES ('3333333333','B1','Prog2');
INSERT INTO StudentBranches VALUES ('4444444444','B1','Prog1');
INSERT INTO StudentBranches VALUES ('5555555555','B1','Prog2');

INSERT INTO Registered VALUES ('1111111111','CCC111');
INSERT INTO Registered VALUES ('1111111111','CCC222');
INSERT INTO Registered VALUES ('1111111111','CCC333');
INSERT INTO Registered VALUES ('2222222222','CCC222');
INSERT INTO Registered VALUES ('5555555555','CCC222');
INSERT INTO Registered VALUES ('5555555555','CCC333');
INSERT INTO Registered VALUES ('4444444444','CCC333');-- overfull course

INSERT INTO Taken VALUES('4444444444','CCC111','5');
INSERT INTO Taken VALUES('4444444444','CCC222','5');
INSERT INTO Taken VALUES('4444444444','CCC333','5');
INSERT INTO Taken VALUES('4444444444','CCC444','5');

INSERT INTO Taken VALUES('5555555555','CCC111','5');
INSERT INTO Taken VALUES('5555555555','CCC222','4');
INSERT INTO Taken VALUES('5555555555','CCC444','3');

INSERT INTO Taken VALUES('2222222222','CCC111','U');
INSERT INTO Taken VALUES('2222222222','CCC222','U');
INSERT INTO Taken VALUES('2222222222','CCC444','U');

INSERT INTO LimitedCourses VALUES ('CCC222',1);
INSERT INTO LimitedCourses VALUES ('CCC333',2);

INSERT INTO WaitingList VALUES('3333333333','CCC222',1);
INSERT INTO WaitingList VALUES('4444444444','CCC222',2);
INSERT INTO WaitingList VALUES('3333333333','CCC333',1);
INSERT INTO WaitingList VALUES('2222222222','CCC333',2);

INSERT INTO Classifications VALUES ('math');
INSERT INTO Classifications VALUES ('research');
INSERT INTO Classifications VALUES ('seminar');

INSERT INTO Classified VALUES ('CCC333','math');
INSERT INTO Classified VALUES ('CCC444','math');
INSERT INTO Classified VALUES ('CCC444','research');
INSERT INTO Classified VALUES ('CCC444','seminar');

INSERT INTO CoursesWithPreRequisite VALUES ('CCC555', 'CCC111');
INSERT INTO CoursesWithPreRequisite VALUES ('CCC555', 'CCC222');

CREATE OR REPLACE FUNCTION reg_func() RETURNS TRIGGER AS $$ --function that is called when a student tries to register to a course.
    DECLARE
        studentCount NUMERIC;
        courseCapacity NUMERIC;
    BEGIN
        IF (EXISTS(         --Checks if the student is already registered, if so an notice is raised
            SELECT student, course FROM Registrations
            WHERE Registrations.course = NEW.course AND Registrations.student = NEW.student
            )
        ) THEN RAISE 'Duplicate user ID, student: % is already registered or on the waiting list for %', NEW.student, NEW.course USING ERRCODE = 'unique_violation';
        ELSEIF (EXISTS(   --Checks if the prerequisites are met, if not a notice is raised
                SELECT preRequisiteCourses FROM CoursesWithPreRequisite -- this is done by selecting all the mandatory courses
                WHERE courseWithPrerequisiteCourse = NEW.course         -- except the courses this student has passed
                EXCEPT
                SELECT course FROM PassedCourses
                WHERE PassedCourses.student = NEW.student
                )
        )THEN RAISE 'User with the ID: % does not meet the requirements in order to take the course with the courseid: %', NEW.student, NEW.course USING ERRCODE = 'check_violation';
        ELSEIF (EXISTS( --if a student has already passed a course, with grade 3 or higher it can not reregister for it and a notice will be raised
                SELECT course FROM PassedCourses WHERE PassedCourses.course = NEW.course AND passedcourses.student = NEW.student
                )
        )THEN RAISE 'User with the ID: % have already completed the course with the courseID: %', NEW.student, NEW.course USING ERRCODE = 'check_violation';
        END IF;

        IF (EXISTS(SELECT course FROM LimitedCourses WHERE LimitedCourses.course = NEW.course))THEN -- Checks if the course is a limited course, if so we need to check if the course is full or not.

            SELECT count(*) INTO studentCount FROM registered WHERE registered.course = NEW.course; -- counts the number of students that are registered to a course
            SELECT capacity INTO courseCapacity FROM limitedcourses WHERE LimitedCourses.course = NEW.course; --fetches the course capacity, that is the number of students that can be registered at most at once

            IF(studentCount < courseCapacity) -- if the course is not full, the student can register to it. else it will be put on a waiting list for said course
                THEN INSERT INTO Registered VALUES (NEW.student, NEW.course);

            ELSE INSERT INTO WaitingList VALUES (NEW.student, NEW.course, nextPositionInQueue(NEW.course));
            END IF;

        ELSE INSERT INTO Registered VALUES (NEW.student, NEW.course);
        END IF;

    RETURN NEW;
    END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION unreg_func() RETURNS TRIGGER AS $$ -- function called when a student unregisteres.
    DECLARE
        studentCount        INT;
        firstStudentInQueue varchar(10);
        courseCapacity      INT;

    BEGIN

    IF(OLD.status = 'registered') THEN --check if students is registered, if so it will be removed from the table registered.

        DELETE FROM Registered WHERE Registered.course = OLD.course AND Registered.student = OLD.STUDENT;

        SELECT capacity INTO courseCapacity FROM LimitedCourses WHERE course = OLD.course; -- fetches the limit of number of students that can be registered at a moment at once.
        SELECT count(*) INTO studentCount FROM Registered WHERE Registered.course = OLD.course; -- number of registered students on the course
        SELECT student  INTO firstStudentInQueue FROM WaitingList WHERE WaitingList.course = OLD.course AND position = '1'; -- the first student in queue for a specific course

        IF(courseCapacity > studentCount AND firstStudentInQueue IS NOT NULL) --Evaluation regarding limited courses, if theres capacity and a student that is first in queue then the student whos on the waiting list is now registered to the course
            THEN
            DELETE FROM WaitingList WHERE WaitingList.course = OLD.course AND WaitingList.student = firstStudentInQueue;
            INSERT INTO Registered VALUES (firstStudentInQueue, OLD.course);
        end if;
    ELSE DELETE FROM WaitingList WHERE WaitingList.course = OLD.course AND WaitingList.student = OLD.student; -- checks if a student is on the waiting list, if so it will be deleted

    END IF;
    RETURN OLD;
    END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION updateposition_func() RETURNS TRIGGER AS $$
    BEGIN
        UPDATE waitinglist SET position = position - 1
        WHERE course = OLD.course AND position > OLD.position;
    RETURN OLD;
    end;
$$ LANGUAGE plpgsql;


CREATE FUNCTION nextPositionInQueue(_course VARCHAR(6)) RETURNS NUMERIC AS $$
    DECLARE
        nextPosition NUMERIC;
    BEGIN

    SELECT count(*) + 1 INTO nextPosition FROM waitinglist WHERE course = _course;
    RETURN nextPosition;
    END;
$$ LANGUAGE plpgsql;



CREATE TRIGGER tr_registration
    INSTEAD OF INSERT
    ON Registrations
    FOR EACH ROW
EXECUTE PROCEDURE reg_func();

CREATE TRIGGER tr_unregistration
    INSTEAD OF DELETE
    ON Registrations
    FOR EACH ROW
EXECUTE PROCEDURE unreg_func();

CREATE TRIGGER tr_updateposition
    AFTER DELETE
    ON waitinglist
    FOR EACH ROW
EXECUTE PROCEDURE updateposition_func();
