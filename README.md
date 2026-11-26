# 学生成绩管理系统 · MySQL 数据库实验

本交付包完成了学生成绩管理系统向 MySQL 的迁移与实现，包含建库建表、测试数据、E-R 图、5 个视图、2 个存储过程、3 个触发器、12 组核心 SQL、运行截图和 Word 实验报告。

**已内置便携版 MySQL 8.4.0**，不需要安装 MySQL、不需要改 PATH、不需要注册 Windows 服务。所有截图和报告图 2 均已用这个便携实例重新运行生成。

## 1. 直接运行（推荐）

按顺序双击根目录下的脚本：

1. `启动MySQL.cmd`：启动便携版 MySQL（端口 3307，仅本机 127.0.0.1）。
2. `运行全部SQL.cmd`：建库、建表、导入测试数据、创建视图/过程/触发器，并执行 12 组核心 SQL。
3. `打开MySQL命令行.cmd`：进入 `mysql>` 交互环境，可自己执行查询。
4. `停止MySQL.cmd`：实验结束后关闭数据库。

便携版说明：

* 端口：`3307`
* 账号：`root`
* 密码：空（仅监听本机，适合课程实验）
* 数据目录：`tools/mysql-data`
* 不需要管理员权限，不影响系统里已安装的其他 MySQL

## 2. 命令行运行

```bat
cd /d D:\shujuku1122
tools\mysql-8.4.0-winx64\bin\mysql.exe --defaults-file=tools\my.ini -u root --default-character-set=utf8mb4 < sql\00_all_in_one.sql
```

进入交互命令行：

```bat
tools\mysql-8.4.0-winx64\bin\mysql.exe --defaults-file=tools\my.ini -u root --table
```

## 3. 目录说明

```text
本文件夹/
├─ 启动MySQL.cmd                启动便携版 MySQL
├─ 停止MySQL.cmd                关闭便携版 MySQL
├─ 运行全部SQL.cmd              一键重建数据库并运行全部 SQL
├─ 打开MySQL命令行.cmd          打开 mysql> 交互命令行
├─ 学生成绩管理系统数据库实验报告.docx
├─ README.md
├─ sql/
│  ├─ 00_all_in_one.sql         全部脚本合并版
│  ├─ 01_schema.sql             建库建表
│  ├─ 02_triggers.sql           函数与触发器
│  ├─ 03_data.sql               测试数据
│  ├─ 04_views.sql              5 个视图
│  ├─ 05_procedures.sql         2 个存储过程
│  ├─ 06_core_queries.sql       12 组核心 SQL
│  ├─ 07_trigger_demo.sql       触发器审计演示
│  ├─ 08_trigger_reject.sql     触发器拦截演示（预期 ERROR 1644）
│  └─ 09_procedure_calls.sql    存储过程调用演示
├─ images/
│  ├─ 01_ER图_Chen.png          Chen 表示法 E-R 图
│  ├─ 02_数据库表关系图.png     表结构与外键关系图
│  ├─ 03~13_运行截图_*.png      本次便携版 MySQL 重新运行生成
│  ├─ ER图_报告版.png           报告用黑白 E-R 图
│  └─ report/结果_查询统计.png  报告图 2 的灰度裁剪图
├─ docs/
│  └─ 数据库对象清单.md         对象、字段与测试数据速查
└─ tools/
   ├─ mysql-8.4.0-winx64/       便携版 MySQL 程序
   ├─ mysql-data/               数据库数据目录
   ├─ my.ini                    端口、字符集配置
   ├─ start_mysql.cmd           数据库启动脚本
   └─ stop_mysql.cmd            数据库停止脚本
```

## 4. 主要设计

* 7 张表：`department`、`teacher`、`classes`、`student`、`course`、`score`、`score_audit`。
* 学生与课程是多对多关系，`score` 为联系表，主键为 `(student_id, course_id)`。
* 总评 = 平时 × 30% + 期末 × 70%，由触发器计算，`CHECK` 约束再次校验。
* `score_audit` 保存修改前/后的成绩、操作账户和时间。
* 5 个视图覆盖成绩明细、学业汇总、课程分析、班级排名和不及格预警。
* 2 个存储过程覆盖成绩录入/修改和班级报告。

## 5. 实验结果

|指标|结果|
|-|-:|
|学生数|22（在读 21，休学 1）|
|课程数|8|
|成绩记录数|105|
|全校平均分|74.9|
|及格 / 不及格|100 / 5 人次|
|总体及格率|95.2%|
|视图 / 存储过程 / 触发器|5 / 2 / 3|

`08_trigger_reject.sql` 返回 `ERROR 1644` 是触发器的预期拦截结果，不是脚本错误。

注：.cmd脚本为本人本机调试用

