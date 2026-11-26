-- =============================================================
-- 学生成绩管理系统 · 08 触发器拦截演示
-- 预期结果：ERROR 1644，休学学生不能录入成绩
-- 该文件单独执行，用于验证 trg_score_bi_calc 的校验逻辑
-- =============================================================
USE student_score_mgmt;
SET NAMES utf8mb4;

INSERT INTO score (student_id, course_id, usual_score, exam_score)
SELECT s.student_id, c.course_id, 80.0, 80.0
FROM student s
JOIN course c ON c.course_code = 'C008'
WHERE s.student_no = '2023022';
