-- =============================================================
-- 学生成绩管理系统 · 一键执行总脚本
-- 环境：MySQL 8.0+ / utf8mb4 / InnoDB
-- 用法：在本 sql 目录执行
--       mysql -u root -p --default-character-set=utf8mb4 < 00_all_in_one.sql
-- 内容：建库建表 -> 函数与触发器 -> 测试数据 -> 视图 -> 存储过程 -> 核心 SQL
-- =============================================================


-- ==================== 01_schema.sql ====================

-- =============================================================
-- 学生成绩管理系统 · 01 建库建表
-- 环境：MySQL 8.4  /  字符集：utf8mb4
-- 执行顺序：01_schema.sql -> 02_triggers.sql -> 03_data.sql
--           -> 04_views.sql -> 05_procedures.sql -> 06_core_queries.sql
-- =============================================================
SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;
DROP DATABASE IF EXISTS student_score_mgmt;
SET FOREIGN_KEY_CHECKS = 1;

CREATE DATABASE student_score_mgmt
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_0900_ai_ci;
USE student_score_mgmt;

-- 1. 院系
CREATE TABLE department (
  dept_id     CHAR(3)      PRIMARY KEY COMMENT '院系编号',
  dept_name   VARCHAR(50)  NOT NULL UNIQUE COMMENT '院系名称',
  office      VARCHAR(50)  COMMENT '办公地点',
  phone       VARCHAR(20)  COMMENT '联系电话'
) ENGINE = InnoDB COMMENT = '院系表';

-- 2. 教师
CREATE TABLE teacher (
  teacher_id   CHAR(4)     PRIMARY KEY COMMENT '教师编号',
  teacher_no   VARCHAR(10) NOT NULL UNIQUE COMMENT '工号',
  teacher_name VARCHAR(30) NOT NULL COMMENT '姓名',
  gender       ENUM('男','女') NOT NULL COMMENT '性别',
  title        VARCHAR(20) NOT NULL DEFAULT '讲师' COMMENT '职称',
  dept_id      CHAR(3)     NOT NULL COMMENT '所属院系',
  CONSTRAINT fk_teacher_dept FOREIGN KEY (dept_id)
    REFERENCES department (dept_id) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE = InnoDB COMMENT = '教师表';

-- 3. 班级
CREATE TABLE classes (
  class_id   CHAR(8)     PRIMARY KEY COMMENT '班级编号',
  class_name VARCHAR(30) NOT NULL UNIQUE COMMENT '班级名称',
  grade      SMALLINT    NOT NULL COMMENT '年级',
  dept_id    CHAR(3)     NOT NULL COMMENT '所属院系',
  CONSTRAINT chk_class_grade CHECK (grade BETWEEN 2000 AND 2100),
  CONSTRAINT fk_class_dept FOREIGN KEY (dept_id)
    REFERENCES department (dept_id) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE = InnoDB COMMENT = '班级表';

-- 4. 学生
CREATE TABLE student (
  student_id   INT          AUTO_INCREMENT PRIMARY KEY COMMENT '学生ID',
  student_no   CHAR(10)     NOT NULL UNIQUE COMMENT '学号',
  student_name VARCHAR(30)  NOT NULL COMMENT '姓名',
  gender       ENUM('男','女') NOT NULL COMMENT '性别',
  birth_date   DATE         COMMENT '出生日期',
  phone        CHAR(11)     COMMENT '手机号',
  email        VARCHAR(60)  COMMENT '邮箱',
  enroll_date  DATE         NOT NULL COMMENT '入学日期',
  class_id     CHAR(8)      NOT NULL COMMENT '所在班级',
  status       ENUM('在读','休学','毕业') NOT NULL DEFAULT '在读' COMMENT '学籍状态',
  CONSTRAINT chk_student_phone CHECK (phone IS NULL OR phone REGEXP '^1[3-9][0-9]{9}$'),
  CONSTRAINT fk_student_class FOREIGN KEY (class_id)
    REFERENCES classes (class_id) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE = InnoDB COMMENT = '学生表';

-- 5. 课程
CREATE TABLE course (
  course_id   INT          AUTO_INCREMENT PRIMARY KEY COMMENT '课程ID',
  course_code CHAR(4)      NOT NULL UNIQUE COMMENT '课程代码',
  course_name VARCHAR(50)  NOT NULL COMMENT '课程名称',
  credit      DECIMAL(3,1) NOT NULL COMMENT '学分',
  hours       SMALLINT     NOT NULL COMMENT '学时',
  course_type ENUM('必修','选修','实践') NOT NULL COMMENT '课程类型',
  semester    VARCHAR(20)  NOT NULL COMMENT '开课学期',
  teacher_id  CHAR(4)      NOT NULL COMMENT '任课教师',
  CONSTRAINT chk_course_credit CHECK (credit BETWEEN 0.5 AND 10.0),
  CONSTRAINT chk_course_hours  CHECK (hours BETWEEN 8 AND 128),
  CONSTRAINT fk_course_teacher FOREIGN KEY (teacher_id)
    REFERENCES teacher (teacher_id) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE = InnoDB COMMENT = '课程表';

-- 6. 成绩（学生与课程的多对多联系表）
CREATE TABLE score (
  student_id  INT          NOT NULL COMMENT '学生ID',
  course_id   INT          NOT NULL COMMENT '课程ID',
  usual_score DECIMAL(5,1) NOT NULL COMMENT '平时成绩（30%）',
  exam_score  DECIMAL(5,1) NOT NULL COMMENT '期末成绩（70%）',
  total_score DECIMAL(5,1) NOT NULL DEFAULT 0 COMMENT '总评成绩，由触发器计算',
  grade_point DECIMAL(3,2) NOT NULL DEFAULT 0 COMMENT '绩点，由触发器计算',
  remark      VARCHAR(100) COMMENT '备注',
  updated_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (student_id, course_id),
  CONSTRAINT chk_usual_score CHECK (usual_score BETWEEN 0 AND 100),
  CONSTRAINT chk_exam_score  CHECK (exam_score  BETWEEN 0 AND 100),
  CONSTRAINT chk_total_score CHECK (total_score BETWEEN 0 AND 100),
  CONSTRAINT chk_total_formula
    CHECK (ABS(total_score - ROUND(usual_score * 0.3 + exam_score * 0.7, 1)) <= 0.05),
  CONSTRAINT fk_score_student FOREIGN KEY (student_id)
    REFERENCES student (student_id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_score_course FOREIGN KEY (course_id)
    REFERENCES course (course_id) ON UPDATE CASCADE ON DELETE RESTRICT,
  KEY idx_score_course (course_id),
  KEY idx_score_total (total_score)
) ENGINE = InnoDB COMMENT = '成绩表';

-- 7. 成绩修改审计（由触发器写入）
CREATE TABLE score_audit (
  audit_id   BIGINT       AUTO_INCREMENT PRIMARY KEY COMMENT '日志ID',
  student_id INT          NOT NULL COMMENT '学生ID',
  course_id  INT          NOT NULL COMMENT '课程ID',
  old_usual  DECIMAL(5,1) NOT NULL COMMENT '修改前平时成绩',
  new_usual  DECIMAL(5,1) NOT NULL COMMENT '修改后平时成绩',
  old_exam   DECIMAL(5,1) NOT NULL COMMENT '修改前期末成绩',
  new_exam   DECIMAL(5,1) NOT NULL COMMENT '修改后期末成绩',
  old_total  DECIMAL(5,1) NOT NULL COMMENT '修改前总评',
  new_total  DECIMAL(5,1) NOT NULL COMMENT '修改后总评',
  operated_by VARCHAR(64) NOT NULL COMMENT '操作账户',
  operated_at DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '操作时间',
  KEY idx_audit_student (student_id, course_id)
) ENGINE = InnoDB COMMENT = '成绩修改审计表';


-- ==================== 02_triggers.sql ====================

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


-- ==================== 03_data.sql ====================

-- =============================================================
-- 学生成绩管理系统 · 03 测试数据
-- 说明：先执行 02_triggers.sql，成绩总评与绩点由触发器生成
-- =============================================================
USE student_score_mgmt;
SET NAMES utf8mb4;

INSERT INTO department (dept_id, dept_name, office, phone) VALUES
('D01', '计算机科学与技术系', '信息楼A301', '010-62781001'),
('D02', '软件工程系',       '信息楼A305', '010-62781002'),
('D03', '人工智能系',       '信息楼B402', '010-62781003');

INSERT INTO teacher (teacher_id, teacher_no, teacher_name, gender, title, dept_id) VALUES
('T001', 'T2001', '张伟', '男', '教授',   'D01'),
('T002', 'T2002', '李娜', '女', '副教授', 'D01'),
('T003', 'T2003', '王强', '男', '讲师',   'D02'),
('T004', 'T2004', '刘洋', '女', '副教授', 'D02'),
('T005', 'T2005', '陈静', '女', '教授',   'D03'),
('T006', 'T2006', '赵磊', '男', '讲师',   'D03');

INSERT INTO classes (class_id, class_name, grade, dept_id) VALUES
('C2023001', '计算机2301班',   2023, 'D01'),
('C2023002', '计算机2302班',   2023, 'D01'),
('C2023003', '软件2301班',     2023, 'D02'),
('C2023004', '人工智能2301班', 2023, 'D03');

INSERT INTO student
(student_no, student_name, gender, birth_date, phone, email, enroll_date, class_id, status) VALUES
('2023001', '陈晨',   '男', '2005-03-12', '13800000001', 'chenchen@stu.edu.cn',   '2023-09-01', 'C2023001', '在读'),
('2023002', '林晓雨', '女', '2005-07-25', '13800000002', 'linxiaoyu@stu.edu.cn',  '2023-09-01', 'C2023001', '在读'),
('2023003', '王子轩', '男', '2004-11-08', '13800000003', 'wangzixuan@stu.edu.cn', '2023-09-01', 'C2023001', '在读'),
('2023004', '赵梦琪', '女', '2005-01-19', '13800000004', 'zhaomengqi@stu.edu.cn', '2023-09-01', 'C2023001', '在读'),
('2023005', '周浩',   '男', '2004-09-30', '13800000005', 'zhouhao@stu.edu.cn',    '2023-09-01', 'C2023001', '在读'),
('2023006', '吴佳怡', '女', '2005-05-16', '13800000006', 'wujiayi@stu.edu.cn',    '2023-09-01', 'C2023001', '在读'),
('2023007', '郑宇',   '男', '2005-02-14', '13800000007', 'zhengyu@stu.edu.cn',    '2023-09-01', 'C2023002', '在读'),
('2023008', '孙悦',   '女', '2004-12-03', '13800000008', 'sunyue@stu.edu.cn',     '2023-09-01', 'C2023002', '在读'),
('2023009', '黄俊杰', '男', '2005-06-21', '13800000009', 'huangjunjie@stu.edu.cn','2023-09-01', 'C2023002', '在读'),
('2023010', '徐静',   '女', '2005-08-09', '13800000010', 'xujing@stu.edu.cn',     '2023-09-01', 'C2023002', '在读'),
('2023011', '胡博文', '男', '2004-10-27', '13800000011', 'hubowen@stu.edu.cn',    '2023-09-01', 'C2023002', '在读'),
('2023012', '朱雨欣', '女', '2005-04-05', '13800000012', 'zhuyuxin@stu.edu.cn',   '2023-09-01', 'C2023003', '在读'),
('2023013', '高翔',   '男', '2005-09-18', '13800000013', 'gaoxiang@stu.edu.cn',   '2023-09-01', 'C2023003', '在读'),
('2023014', '何欣',   '女', '2004-11-22', '13800000014', 'hexin@stu.edu.cn',      '2023-09-01', 'C2023003', '在读'),
('2023015', '马超',   '男', '2005-03-30', '13800000015', 'machao@stu.edu.cn',     '2023-09-01', 'C2023003', '在读'),
('2023016', '罗嘉',   '男', '2005-01-11', '13800000016', 'luojia@stu.edu.cn',     '2023-09-01', 'C2023003', '在读'),
('2023017', '谢婷婷', '女', '2005-06-08', '13800000017', 'xietingting@stu.edu.cn','2023-09-01', 'C2023004', '在读'),
('2023018', '唐磊',   '男', '2004-08-15', '13800000018', 'tanglei@stu.edu.cn',    '2023-09-01', 'C2023004', '在读'),
('2023019', '曹雪',   '女', '2005-10-02', '13800000019', 'caoxue@stu.edu.cn',     '2023-09-01', 'C2023004', '在读'),
('2023020', '彭宇航', '男', '2005-02-26', '13800000020', 'pengyuhang@stu.edu.cn', '2023-09-01', 'C2023004', '在读'),
('2023021', '张雨桐', '女', '2005-07-14', '13800000021', 'zhangyutong@stu.edu.cn','2023-09-01', 'C2023004', '在读'),
('2023022', '韩泽',   '男', '2005-05-09', '13800000022', 'hanze@stu.edu.cn',      '2023-09-01', 'C2023004', '休学');

INSERT INTO course
(course_code, course_name, credit, hours, course_type, semester, teacher_id) VALUES
('C001', '数据库原理',       4.0, 64, '必修', '2025-2026-1', 'T001'),
('C002', '数据结构',         4.0, 64, '必修', '2025-2026-1', 'T002'),
('C003', '操作系统',         3.5, 56, '必修', '2025-2026-2', 'T001'),
('C004', 'Java程序设计',     3.0, 48, '必修', '2025-2026-1', 'T003'),
('C005', '软件工程导论',     2.5, 40, '必修', '2025-2026-2', 'T004'),
('C006', '机器学习基础',     3.0, 48, '选修', '2025-2026-1', 'T005'),
('C007', '人工智能导论',     2.0, 32, '选修', '2025-2026-1', 'T005'),
('C008', '数据库课程设计',   2.0, 32, '实践', '2025-2026-2', 'T001');

-- 按专业培养方案批量生成成绩：不同班级修读不同课程组合
-- 平时/期末成绩使用确定性公式生成，便于重复实验；总评与绩点由触发器计算
INSERT INTO score (student_id, course_id, usual_score, exam_score, remark)
SELECT s.student_id,
       c.course_id,
       60 + MOD(s.student_id * 7 + c.course_id * 3, 36) AS usual_score,
       52 + MOD(s.student_id * 11 + c.course_id * 7, 44) AS exam_score,
       CASE WHEN 52 + MOD(s.student_id * 11 + c.course_id * 7, 44) < 60
            THEN '期末不及格，需补考' ELSE '正常' END
FROM student s
JOIN course c
  ON (s.class_id IN ('C2023001','C2023002')
      AND c.course_code IN ('C001','C002','C003','C004','C005'))
  OR (s.class_id = 'C2023003'
      AND c.course_code IN ('C002','C004','C005','C006','C007'))
  OR (s.class_id = 'C2023004'
      AND c.course_code IN ('C002','C004','C006','C007','C008'))
WHERE s.status = '在读';


-- ==================== 04_views.sql ====================

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


-- ==================== 05_procedures.sql ====================

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


-- ==================== 06_core_queries.sql ====================

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
