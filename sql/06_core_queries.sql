-- =============================================================
-- 学生成绩管理系统 · 06 核心 SQL（12 组，可直接执行）
-- 覆盖：多表连接、分组聚合、子查询、窗口函数、增删改查
-- 注意：Q3-Q5 使用学号 2023023 的临时学生演示，执行后自动清理
-- =============================================================
USE student_score_mgmt;
SET NAMES utf8mb4;

-- Q1 多表连接：数据库原理课程成绩单（学生、班级、课程、教师、成绩 5 表）
SELECT s.student_no, s.student_name, cl.class_name, c.course_name,
       t.teacher_name, sc.usual_score, sc.exam_score, sc.total_score
FROM student s
JOIN score sc    ON sc.student_id = s.student_id
JOIN course c    ON c.course_id = sc.course_id
JOIN teacher t   ON t.teacher_id = c.teacher_id
JOIN classes cl  ON cl.class_id = s.class_id
WHERE c.course_code = 'C001'
ORDER BY sc.total_score DESC, s.student_no
LIMIT 8;

-- Q2 分组聚合：各课程成绩统计与及格率
SELECT c.course_code, c.course_name, COUNT(*) AS 人数,
       ROUND(AVG(sc.total_score), 1) AS 平均分,
       MAX(sc.total_score) AS 最高分, MIN(sc.total_score) AS 最低分,
       SUM(sc.total_score >= 60) AS 及格人数,
       CONCAT(ROUND(100 * AVG(sc.total_score >= 60), 1), '%') AS 及格率
FROM course c
JOIN score sc ON sc.course_id = c.course_id
GROUP BY c.course_id, c.course_code, c.course_name
ORDER BY c.course_code;

-- Q3 增：新增一名转入学生（INSERT IGNORE 保证脚本可重复执行）
INSERT IGNORE INTO student
(student_no, student_name, gender, birth_date, phone, email, enroll_date, class_id, status)
VALUES
('2023023', '苏晴', '女', '2005-11-11', '13800000023', 'suqing@stu.edu.cn',
 '2023-09-01', 'C2023004', '在读');
SELECT student_no, student_name, class_id, phone, status
FROM student WHERE student_no = '2023023';

-- Q4 改：修改该生联系方式
UPDATE student
SET phone = '13900000023', email = 'suqing_new@stu.edu.cn'
WHERE student_no = '2023023';
SELECT student_no, student_name, phone, email FROM student WHERE student_no = '2023023';

-- Q5 删：删除临时测试学生
DELETE FROM student WHERE student_no = '2023023';
SELECT COUNT(*) AS 剩余学生数 FROM student;

-- Q6 分组聚合 + HAVING：平均分高于 74 的班级
SELECT cl.class_name, COUNT(DISTINCT s.student_id) AS 人数,
       ROUND(AVG(sc.total_score), 1) AS 班级平均分
FROM classes cl
JOIN student s ON s.class_id = cl.class_id
JOIN score sc  ON sc.student_id = s.student_id
GROUP BY cl.class_id, cl.class_name
HAVING AVG(sc.total_score) > 74
ORDER BY 班级平均分 DESC;

-- Q7 子查询：平均分高于全校平均分的学生
SELECT s.student_no, s.student_name, ROUND(AVG(sc.total_score), 1) AS 个人平均分
FROM student s
JOIN score sc ON sc.student_id = s.student_id
GROUP BY s.student_id, s.student_no, s.student_name
HAVING AVG(sc.total_score) > (SELECT AVG(total_score) FROM score)
ORDER BY 个人平均分 DESC
LIMIT 10;

-- Q8 相关子查询 NOT EXISTS：没有不及格课程的学生
SELECT s.student_no, s.student_name, cl.class_name
FROM student s
JOIN classes cl ON cl.class_id = s.class_id
WHERE s.status = '在读'
  AND NOT EXISTS (
    SELECT 1 FROM score sc
    WHERE sc.student_id = s.student_id AND sc.total_score < 60
  )
ORDER BY s.student_no
LIMIT 10;

-- Q9 窗口函数：各班前三名
SELECT class_name, rank_in_class, student_no, student_name, avg_score
FROM v_class_score_ranking
WHERE rank_in_class <= 3
ORDER BY class_name, rank_in_class;

-- Q10 视图查询：学业奖学金候选人（无挂科且绩点不低于 2.6）
SELECT student_no, student_name, class_name, course_count,
       earned_credits, avg_score, gpa, failed_count
FROM v_student_grade_summary
WHERE failed_count = 0 AND gpa >= 2.6
ORDER BY gpa DESC, avg_score DESC
LIMIT 10;

-- Q11 视图查询：不及格课程教学预警
SELECT student_no, student_name, class_name, course_name,
       total_score, score_gap
FROM v_failed_student_courses
ORDER BY score_gap DESC;

-- Q12 统计查询：全校成绩总览
SELECT COUNT(*) AS 成绩记录数,
       COUNT(DISTINCT student_id) AS 参考人数,
       ROUND(AVG(total_score), 1) AS 全校平均分,
       SUM(total_score >= 60) AS 及格人次,
       SUM(total_score < 60) AS 不及格人次,
       ROUND(100 * AVG(total_score >= 60), 1) AS 总体及格率
FROM score;
