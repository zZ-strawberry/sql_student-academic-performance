-- =============================================================
-- 学生成绩管理系统 · 04 视图
-- =============================================================
USE student_score_mgmt;
SET NAMES utf8mb4;

-- 视图 1：学生成绩明细（多表连接）
CREATE OR REPLACE VIEW v_student_score_detail AS
SELECT s.student_no,
       s.student_name,
       cl.class_name,
       d.dept_name,
       c.course_code,
       c.course_name,
       c.credit,
       c.course_type,
       c.semester,
       t.teacher_name,
       sc.usual_score,
       sc.exam_score,
       sc.total_score,
       sc.grade_point,
       CASE
         WHEN sc.total_score >= 90 THEN '优秀'
         WHEN sc.total_score >= 80 THEN '良好'
         WHEN sc.total_score >= 70 THEN '中等'
         WHEN sc.total_score >= 60 THEN '及格'
         ELSE '不及格'
       END AS grade_level
FROM score sc
JOIN student s  ON s.student_id = sc.student_id
JOIN classes cl ON cl.class_id = s.class_id
JOIN department d ON d.dept_id = cl.dept_id
JOIN course c   ON c.course_id = sc.course_id
JOIN teacher t  ON t.teacher_id = c.teacher_id;

-- 视图 2：学生学业汇总（分组聚合 + 加权绩点）
CREATE OR REPLACE VIEW v_student_grade_summary AS
SELECT s.student_no,
       s.student_name,
       cl.class_name,
       COUNT(sc.course_id) AS course_count,
       ROUND(SUM(c.credit), 1) AS registered_credits,
       ROUND(SUM(CASE WHEN sc.total_score >= 60 THEN c.credit ELSE 0 END), 1) AS earned_credits,
       ROUND(AVG(sc.total_score), 1) AS avg_score,
       ROUND(SUM(sc.grade_point * c.credit) / NULLIF(SUM(c.credit), 0), 2) AS gpa,
       SUM(CASE WHEN sc.total_score < 60 THEN 1 ELSE 0 END) AS failed_count
FROM score sc
JOIN student s  ON s.student_id = sc.student_id
JOIN classes cl ON cl.class_id = s.class_id
JOIN course c   ON c.course_id = sc.course_id
GROUP BY s.student_id, s.student_no, s.student_name, cl.class_name;

-- 视图 3：课程成绩分析（及格率、优秀率）
CREATE OR REPLACE VIEW v_course_score_analysis AS
SELECT c.course_code,
       c.course_name,
       t.teacher_name,
       c.credit,
       c.course_type,
       c.semester,
       COUNT(sc.student_id) AS student_count,
       ROUND(AVG(sc.total_score), 1) AS avg_score,
       MAX(sc.total_score) AS max_score,
       MIN(sc.total_score) AS min_score,
       SUM(CASE WHEN sc.total_score >= 60 THEN 1 ELSE 0 END) AS pass_count,
       ROUND(100 * SUM(CASE WHEN sc.total_score >= 60 THEN 1 ELSE 0 END)
             / NULLIF(COUNT(sc.student_id), 0), 1) AS pass_rate,
       ROUND(100 * SUM(CASE WHEN sc.total_score >= 85 THEN 1 ELSE 0 END)
             / NULLIF(COUNT(sc.student_id), 0), 1) AS excellent_rate
FROM course c
JOIN teacher t ON t.teacher_id = c.teacher_id
LEFT JOIN score sc ON sc.course_id = c.course_id
GROUP BY c.course_id, c.course_code, c.course_name, t.teacher_name,
         c.credit, c.course_type, c.semester;

-- 视图 4：班级成绩排名（窗口函数）
CREATE OR REPLACE VIEW v_class_score_ranking AS
SELECT class_name,
       student_no,
       student_name,
       avg_score,
       DENSE_RANK() OVER (PARTITION BY class_id ORDER BY avg_score DESC) AS rank_in_class
FROM (
  SELECT cl.class_id, cl.class_name, s.student_no, s.student_name,
         ROUND(AVG(sc.total_score), 1) AS avg_score
  FROM score sc
  JOIN student s  ON s.student_id = sc.student_id
  JOIN classes cl ON cl.class_id = s.class_id
  GROUP BY cl.class_id, cl.class_name, s.student_id, s.student_no, s.student_name
) t;

-- 视图 5：不及格学生清单（教学预警）
CREATE OR REPLACE VIEW v_failed_student_courses AS
SELECT s.student_no,
       s.student_name,
       cl.class_name,
       c.course_code,
       c.course_name,
       t.teacher_name,
       sc.total_score,
       ROUND(60 - sc.total_score, 1) AS score_gap
FROM score sc
JOIN student s  ON s.student_id = sc.student_id
JOIN classes cl ON cl.class_id = s.class_id
JOIN course c   ON c.course_id = sc.course_id
JOIN teacher t  ON t.teacher_id = c.teacher_id
WHERE sc.total_score < 60;
