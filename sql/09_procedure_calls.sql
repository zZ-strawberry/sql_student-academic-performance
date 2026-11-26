-- =============================================================
-- 学生成绩管理系统 · 09 存储过程调用演示
-- 演示成绩修改、结果变量返回、班级报告双结果集
-- 演示结束后恢复原成绩，保证数据与初始状态一致
-- =============================================================
USE student_score_mgmt;
SET NAMES utf8mb4;

-- 修改陈晨“数据库原理”成绩
CALL sp_save_score('2023001', 'C001', 80.0, 85.0, @code, @message);
SELECT @code AS 返回码, @message AS 返回信息;

SELECT s.student_no, c.course_code, sc.usual_score, sc.exam_score,
       sc.total_score, sc.grade_point
FROM score sc
JOIN student s ON s.student_id = sc.student_id
JOIN course c  ON c.course_id = sc.course_id
WHERE s.student_no = '2023001' AND c.course_code = 'C001';

-- 恢复原成绩（触发器同步重算并留痕）
CALL sp_save_score('2023001', 'C001', 70.0, 70.0, @code, @message);
SELECT @code AS 返回码, @message AS 返回信息;

-- 班级报告：结果集 1 为班级概览，结果集 2 为学生排名
CALL sp_class_report('计算机2301班');
