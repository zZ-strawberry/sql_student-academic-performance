-- =============================================================
-- 学生成绩管理系统 · 02 函数与触发器
-- 说明：成绩总评 = 平时成绩 × 30% + 期末成绩 × 70%
--       触发器负责校验、自动计算与修改留痕
-- =============================================================
USE student_score_mgmt;
SET NAMES utf8mb4;

DROP TRIGGER IF EXISTS trg_score_bi_calc;
DROP TRIGGER IF EXISTS trg_score_bu_calc;
DROP TRIGGER IF EXISTS trg_score_au_audit;
DROP FUNCTION IF EXISTS fn_grade_point;

DELIMITER $$

-- 总评成绩到绩点的换算函数
CREATE FUNCTION fn_grade_point(p_score DECIMAL(5,1))
RETURNS DECIMAL(3,2)
DETERMINISTIC
NO SQL
BEGIN
  RETURN CASE
    WHEN p_score >= 90 THEN 4.00
    WHEN p_score >= 85 THEN 3.70
    WHEN p_score >= 82 THEN 3.30
    WHEN p_score >= 78 THEN 3.00
    WHEN p_score >= 75 THEN 2.70
    WHEN p_score >= 72 THEN 2.30
    WHEN p_score >= 68 THEN 2.00
    WHEN p_score >= 64 THEN 1.50
    WHEN p_score >= 60 THEN 1.00
    ELSE 0.00
  END;
END$$

-- 触发器 1：新增成绩前校验并自动计算总评、绩点
CREATE TRIGGER trg_score_bi_calc
BEFORE INSERT ON score
FOR EACH ROW
BEGIN
  IF NEW.usual_score < 0 OR NEW.usual_score > 100
     OR NEW.exam_score < 0 OR NEW.exam_score > 100 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '成绩必须在 0 到 100 之间';
  END IF;
  IF (SELECT status FROM student WHERE student_id = NEW.student_id) <> '在读' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '非在读学生不能录入成绩';
  END IF;
  SET NEW.total_score = ROUND(NEW.usual_score * 0.3 + NEW.exam_score * 0.7, 1);
  SET NEW.grade_point = fn_grade_point(NEW.total_score);
  SET NEW.updated_at = NOW();
END$$

-- 触发器 2：修改成绩前重新计算总评、绩点
CREATE TRIGGER trg_score_bu_calc
BEFORE UPDATE ON score
FOR EACH ROW
BEGIN
  IF NEW.usual_score < 0 OR NEW.usual_score > 100
     OR NEW.exam_score < 0 OR NEW.exam_score > 100 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '成绩必须在 0 到 100 之间';
  END IF;
  SET NEW.total_score = ROUND(NEW.usual_score * 0.3 + NEW.exam_score * 0.7, 1);
  SET NEW.grade_point = fn_grade_point(NEW.total_score);
  SET NEW.updated_at = NOW();
END$$

-- 触发器 3：成绩修改后写入审计表
CREATE TRIGGER trg_score_au_audit
AFTER UPDATE ON score
FOR EACH ROW
BEGIN
  IF OLD.usual_score <> NEW.usual_score OR OLD.exam_score <> NEW.exam_score THEN
    INSERT INTO score_audit
      (student_id, course_id, old_usual, new_usual, old_exam, new_exam,
       old_total, new_total, operated_by)
    VALUES
      (OLD.student_id, OLD.course_id, OLD.usual_score, NEW.usual_score,
       OLD.exam_score, NEW.exam_score, OLD.total_score, NEW.total_score, CURRENT_USER());
  END IF;
END$$

DELIMITER ;
