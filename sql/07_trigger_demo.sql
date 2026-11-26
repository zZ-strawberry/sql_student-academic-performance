-- =============================================================
-- 学生成绩管理系统 · 07 触发器演示（事务内执行并回滚，不污染数据）
-- 演示 1：更新成绩时自动重算总评/绩点，并写入审计表
-- =============================================================
USE student_score_mgmt;
SET NAMES utf8mb4;

START TRANSACTION;

SELECT '更新前' AS 阶段, s.student_no, c.course_code,
       sc.usual_score, sc.exam_score, sc.total_score, sc.grade_point
FROM score sc
JOIN student s ON s.student_id = sc.student_id
JOIN course c  ON c.course_id = sc.course_id
WHERE s.student_no = '2023001' AND c.course_code = 'C001';

UPDATE score sc
JOIN student s ON s.student_id = sc.student_id
JOIN course c  ON c.course_id = sc.course_id
SET sc.usual_score = 88.0, sc.exam_score = 94.0
WHERE s.student_no = '2023001' AND c.course_code = 'C001';

SELECT '更新后' AS 阶段, s.student_no, c.course_code,
       sc.usual_score, sc.exam_score, sc.total_score, sc.grade_point
FROM score sc
JOIN student s ON s.student_id = sc.student_id
JOIN course c  ON c.course_id = sc.course_id
WHERE s.student_no = '2023001' AND c.course_code = 'C001';

SELECT audit_id, student_id, course_id, old_usual, new_usual,
       old_exam, new_exam, old_total, new_total, operated_by
FROM score_audit
ORDER BY audit_id DESC
LIMIT 1;

ROLLBACK;

SELECT '事务已回滚' AS 说明, sc.usual_score, sc.exam_score, sc.total_score
FROM score sc
JOIN student s ON s.student_id = sc.student_id
JOIN course c  ON c.course_id = sc.course_id
WHERE s.student_no = '2023001' AND c.course_code = 'C001';
