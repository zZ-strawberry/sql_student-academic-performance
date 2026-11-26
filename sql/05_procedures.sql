-- =============================================================
-- 学生成绩管理系统 · 05 存储过程
-- =============================================================
USE student_score_mgmt;
SET NAMES utf8mb4;

DROP PROCEDURE IF EXISTS sp_save_score;
DROP PROCEDURE IF EXISTS sp_class_report;

DELIMITER $$

-- 存储过程 1：录入或修改一名学生的成绩（事务 + 触发器校验）
CREATE PROCEDURE sp_save_score(
  IN  p_student_no  CHAR(10),
  IN  p_course_code CHAR(4),
  IN  p_usual       DECIMAL(5,1),
  IN  p_exam        DECIMAL(5,1),
  OUT p_code        INT,
  OUT p_message     VARCHAR(120)
)
proc: BEGIN
  DECLARE v_student_id INT DEFAULT NULL;
  DECLARE v_course_id  INT DEFAULT NULL;
  DECLARE v_exists     INT DEFAULT 0;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    GET DIAGNOSTICS CONDITION 1 p_message = MESSAGE_TEXT;
    SET p_code = -1;
    SET p_message = CONCAT('保存失败：', p_message);
  END;

  IF p_usual NOT BETWEEN 0 AND 100 OR p_exam NOT BETWEEN 0 AND 100 THEN
    SET p_code = -3;
    SET p_message = '成绩必须在 0 到 100 之间';
    LEAVE proc;
  END IF;

  START TRANSACTION;

  SET v_student_id = (SELECT student_id FROM student WHERE student_no = p_student_no);
  SET v_course_id  = (SELECT course_id  FROM course  WHERE course_code = p_course_code);

  IF v_student_id IS NULL THEN
    SET p_code = -2; SET p_message = '学号不存在'; ROLLBACK; LEAVE proc;
  END IF;
  IF v_course_id IS NULL THEN
    SET p_code = -2; SET p_message = '课程代码不存在'; ROLLBACK; LEAVE proc;
  END IF;

  SET v_exists = (SELECT COUNT(*) FROM score
                  WHERE student_id = v_student_id AND course_id = v_course_id);

  IF v_exists > 0 THEN
    UPDATE score
       SET usual_score = p_usual, exam_score = p_exam
     WHERE student_id = v_student_id AND course_id = v_course_id;
    SET p_message = '成绩修改成功';
  ELSE
    INSERT INTO score (student_id, course_id, usual_score, exam_score)
    VALUES (v_student_id, v_course_id, p_usual, p_exam);
    SET p_message = '成绩录入成功';
  END IF;

  SET p_code = 0;
  COMMIT;
END$$

-- 存储过程 2：班级成绩报告（两个结果集：班级概览 + 学生排名）
CREATE PROCEDURE sp_class_report(IN p_class_name VARCHAR(30))
BEGIN
  IF NOT EXISTS (SELECT 1 FROM classes WHERE class_name = p_class_name) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '班级不存在';
  END IF;

  SELECT cl.class_name,
         COUNT(DISTINCT s.student_id) AS student_count,
         COUNT(sc.course_id) AS score_count,
         ROUND(AVG(sc.total_score), 1) AS class_avg,
         MAX(sc.total_score) AS max_score,
         MIN(sc.total_score) AS min_score,
         ROUND(100 * SUM(CASE WHEN sc.total_score >= 60 THEN 1 ELSE 0 END)
               / NULLIF(COUNT(sc.course_id), 0), 1) AS pass_rate
  FROM classes cl
  JOIN student s ON s.class_id = cl.class_id AND s.status = '在读'
  LEFT JOIN score sc ON sc.student_id = s.student_id
  WHERE cl.class_name = p_class_name
  GROUP BY cl.class_id, cl.class_name;

  SELECT student_no, student_name, avg_score, rank_in_class
  FROM v_class_score_ranking
  WHERE class_name = p_class_name
  ORDER BY rank_in_class, student_no;
END$$

DELIMITER ;
