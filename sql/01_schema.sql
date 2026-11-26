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
