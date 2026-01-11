-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: Jan 11, 2026 at 08:19 AM
-- Server version: 10.4.32-MariaDB
-- PHP Version: 8.2.12

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `analyzer`
--

-- --------------------------------------------------------

--
-- Table structure for table `admin`
--

CREATE TABLE `admin` (
  `id` int(11) NOT NULL,
  `email` varchar(255) NOT NULL,
  `passwordHash` varchar(255) NOT NULL,
  `name` varchar(255) NOT NULL,
  `isActive` tinyint(1) NOT NULL DEFAULT 1,
  `role` enum('SUPER_ADMIN','ADMIN','USER') NOT NULL DEFAULT 'USER',
  `createdAt` timestamp NOT NULL DEFAULT current_timestamp(),
  `updatedAt` timestamp NOT NULL DEFAULT current_timestamp(),
  `company_id` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `admin`
--

INSERT INTO `admin` (`id`, `email`, `passwordHash`, `name`, `isActive`, `role`, `createdAt`, `updatedAt`, `company_id`) VALUES
(14, 'ayesh@activelk.com', '$2b$10$Rwx.y9xAor08KP5BiQvfMOapK/vcgWxN.LgFekvHvAkBmD35aFJqe', 'ayesh', 1, 'ADMIN', '2025-12-08 04:52:52', '2025-12-08 04:52:52', 14);

-- --------------------------------------------------------

--
-- Table structure for table `adminpermission`
--

CREATE TABLE `adminpermission` (
  `id` int(11) NOT NULL,
  `adminId` int(11) NOT NULL,
  `permissionId` int(11) NOT NULL,
  `createdAt` timestamp NOT NULL DEFAULT current_timestamp(),
  `updatedAt` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_logs`
--

CREATE TABLE `app_logs` (
  `id` int(11) NOT NULL,
  `related_table` varchar(100) DEFAULT NULL,
  `related_table_id` int(11) DEFAULT NULL,
  `severity` int(11) NOT NULL,
  `message` varchar(100) NOT NULL,
  `admin_id` int(11) DEFAULT NULL,
  `action` varchar(100) NOT NULL,
  `status_code` int(11) NOT NULL,
  `additional_data` varchar(100) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `app_logs`
--

INSERT INTO `app_logs` (`id`, `related_table`, `related_table_id`, `severity`, `message`, `admin_id`, `action`, `status_code`, `additional_data`, `created_at`, `updated_at`) VALUES
(1, NULL, NULL, 1, 'Session validation attempt', NULL, 'SESSION_VALIDATE_API', 200, '{\"hasSessionToken\":false,\"sessionTokenPreview\":null}', '2025-11-10 21:59:40', '2025-11-10 21:59:40'),
(2, NULL, NULL, 2, 'Session validation failed: No session token provided', NULL, 'SESSION_VALIDATE_API', 400, NULL, '2025-11-10 21:59:40', '2025-11-10 21:59:40'),
(3, NULL, NULL, 1, 'Session validation attempt', NULL, 'SESSION_VALIDATE_API', 200, '{\"hasSessionToken\":false,\"sessionTokenPreview\":null}', '2025-11-10 22:39:27', '2025-11-10 22:39:27'),
(4, NULL, NULL, 2, 'Session validation failed: No session token provided', NULL, 'SESSION_VALIDATE_API', 400, NULL, '2025-11-10 22:39:27', '2025-11-10 22:39:27'),
(5, NULL, NULL, 1, 'Session validation attempt', NULL, 'SESSION_VALIDATE_API', 200, '{\"hasSessionToken\":false,\"sessionTokenPreview\":null}', '2025-11-10 22:40:02', '2025-11-10 22:40:02'),
(6, NULL, NULL, 2, 'Session validation failed: No session token provided', NULL, 'SESSION_VALIDATE_API', 400, NULL, '2025-11-10 22:40:02', '2025-11-10 22:40:02'),
(7, NULL, NULL, 2, 'Login attempt with email: active@example.com', NULL, 'LOGIN_ATTEMPT_API', 200, '{\"email\":\"active@example.com\"}', '2025-11-10 22:40:20', '2025-11-10 22:40:20'),
(8, NULL, NULL, 1, 'User active@example.com logged in successfully', NULL, 'LOGIN_SUCCESS_API', 200, NULL, '2025-11-10 22:40:20', '2025-11-10 22:40:20'),
(9, NULL, NULL, 1, 'Session validation attempt', NULL, 'SESSION_VALIDATE_API', 200, '{\"hasSessionToken\":true,\"sessionTokenPreview\":\"0764d4a885...\"}', '2025-11-10 22:40:21', '2025-11-10 22:40:21'),
(10, NULL, NULL, 1, 'Session validated successfully for user active@example.com', NULL, 'SESSION_VALIDATE_SUCCESS_API', 200, NULL, '2025-11-10 22:40:21', '2025-11-10 22:40:21'),
(11, NULL, NULL, 1, 'Session validation attempt', NULL, 'SESSION_VALIDATE_API', 200, '{\"hasSessionToken\":true,\"sessionTokenPreview\":\"0764d4a885...\"}', '2025-11-10 22:40:25', '2025-11-10 22:40:25'),
(12, NULL, NULL, 1, 'Session validated successfully for user active@example.com', NULL, 'SESSION_VALIDATE_SUCCESS_API', 200, NULL, '2025-11-10 22:40:25', '2025-11-10 22:40:25'),
(13, NULL, NULL, 1, 'Fetching devices data', NULL, 'FETCH_DEVICES', 200, NULL, '2025-11-10 22:40:25', '2025-11-10 22:40:25'),
(14, NULL, NULL, 4, 'Error fetching devices: \nInvalid `prisma.devices.findMany()` invocation in\nD:\\PROJECTS\\NEXT\\syslog-d', NULL, 'FETCH_DEVICES_ERROR', 500, NULL, '2025-11-10 22:40:26', '2025-11-10 22:40:26'),
(15, NULL, NULL, 1, 'Session validation attempt', NULL, 'SESSION_VALIDATE_API', 200, '{\"hasSessionToken\":true,\"sessionTokenPreview\":\"0764d4a885...\"}', '2025-11-10 22:40:26', '2025-11-10 22:40:26'),
(16, NULL, NULL, 1, 'Session validated successfully for user active@example.com', NULL, 'SESSION_VALIDATE_SUCCESS_API', 200, NULL, '2025-11-10 22:40:26', '2025-11-10 22:40:26'),
(17, NULL, NULL, 1, 'Fetching devices data', NULL, 'FETCH_DEVICES', 200, NULL, '2025-11-10 22:40:26', '2025-11-10 22:40:26'),
(18, NULL, NULL, 4, 'Error fetching devices: \nInvalid `prisma.devices.findMany()` invocation in\nD:\\PROJECTS\\NEXT\\syslog-d', NULL, 'FETCH_DEVICES_ERROR', 500, NULL, '2025-11-10 22:40:27', '2025-11-10 22:40:27'),
(19, NULL, NULL, 1, 'Session validation attempt', NULL, 'SESSION_VALIDATE_API', 200, '{\"hasSessionToken\":true,\"sessionTokenPreview\":\"0764d4a885...\"}', '2025-11-10 22:40:27', '2025-11-10 22:40:27'),
(20, NULL, NULL, 1, 'Session validated successfully for user active@example.com', NULL, 'SESSION_VALIDATE_SUCCESS_API', 200, NULL, '2025-11-10 22:40:27', '2025-11-10 22:40:27'),
-- --------------------------------------------------------

--
-- Table structure for table `collectors`
--

CREATE TABLE `collectors` (
  `id` int(11) NOT NULL,
  `name` varchar(255) NOT NULL,
  `secret_key` varchar(255) NOT NULL,
  `last_fetched_id` int(11) DEFAULT 0,
  `is_active` tinyint(1) DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `ip` varchar(100) DEFAULT NULL,
  `domain` varchar(100) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `collectors`
--

INSERT INTO `collectors` (`id`, `name`, `secret_key`, `last_fetched_id`, `is_active`, `created_at`, `updated_at`, `ip`, `domain`) VALUES
(6, 'Alpha Corp', 'collector-secret-2', 0, 1, '2025-11-26 01:32:29', '2025-11-26 01:32:29', '192.168.2.10', '');

-- --------------------------------------------------------

--
-- Table structure for table `company`
--

CREATE TABLE `company` (
  `id` int(11) NOT NULL,
  `act_key` varchar(100) DEFAULT NULL,
  `collector_id` int(11) DEFAULT NULL,
  `port` int(11) DEFAULT NULL,
  `log_quota` int(11) NOT NULL,
  `device_count` int(11) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `is_validated` tinyint(1) DEFAULT 0,
  `name` varchar(255) DEFAULT NULL,
  `plan` varchar(50) NOT NULL,
  `pkg_ending_date` timestamp NULL DEFAULT NULL,
  `validated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `company`
--

INSERT INTO `company` (`id`, `act_key`, `collector_id`, `port`, `log_quota`, `device_count`, `created_at`, `updated_at`, `is_validated`, `name`, `plan`, `pkg_ending_date`, `validated_at`) VALUES
(14, 'AU3F-6VCZ-GABC', NULL, 5, 1000, 5, '2025-12-08 04:52:52', '2025-12-08 04:52:52', 1, 'Alpha Corp', 'Basic Package', '2025-12-24 03:47:14', '2025-12-08 04:52:52');

-- --------------------------------------------------------

--
-- Table structure for table `devices`
--

CREATE TABLE `devices` (
  `id` int(11) NOT NULL,
  `collector_id` int(11) DEFAULT NULL,
  `port` int(11) NOT NULL,
  `device_name` varchar(255) NOT NULL,
  `status` tinyint(1) DEFAULT 1,
  `log_quota` int(11) DEFAULT 10000,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `company_id` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `field_extraction_rules`
--

CREATE TABLE `field_extraction_rules` (
  `id` int(11) NOT NULL,
  `pattern_id` int(11) NOT NULL,
  `field_name` varchar(100) NOT NULL,
  `regex_pattern` varchar(500) NOT NULL,
  `regex_group_index` int(11) DEFAULT 1,
  `default_value` varchar(255) DEFAULT NULL,
  `is_required` tinyint(1) DEFAULT 0,
  `data_type` enum('string','integer','float','datetime','json') DEFAULT 'string',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `field_extraction_rules`
--

INSERT INTO `field_extraction_rules` (`id`, `pattern_id`, `field_name`, `regex_pattern`, `regex_group_index`, `default_value`, `is_required`, `data_type`, `created_at`) VALUES
(2, 1, 'event_type', '/Event:\\s*(\\w+)/', 1, NULL, 1, 'string', '2025-11-11 06:02:03'),
(3, 1, 'file_path', '/Path:\\s*(.+?)(?:\\s*->|,\\s*File)/', 1, NULL, 1, 'string', '2025-11-11 06:02:03'),
(4, 1, 'destination_path', '/Path:\\s*.+?\\s*->\\s*(.+?),\\s*File/', 1, NULL, 0, 'string', '2025-11-11 06:02:03'),
(5, 1, 'file_folder_type', '/File\\/Folder:\\s*(\\w+)/', 1, NULL, 1, 'string', '2025-11-11 06:02:03'),
(6, 1, 'file_size', '/Size:\\s*(.+?),\\s*User/', 1, NULL, 0, 'string', '2025-11-11 06:02:03'),
(7, 1, 'username', '/User:\\s*(.+?),\\s*IP/', 1, NULL, 1, 'string', '2025-11-11 06:02:03'),
(8, 1, 'user_ip', '/IP:\\s*(.+)$/', 1, NULL, 1, 'string', '2025-11-11 06:02:03'),
(9, 2, 'username', '/^(.+?):#011/', 1, NULL, 1, 'string', '2025-11-11 06:02:03'),
(10, 2, 'admin_action', '/#011(.+)$/', 1, NULL, 1, 'string', '2025-11-11 06:02:03'),
(11, 2, 'event_type', '', 1, 'system_admin', 0, 'string', '2025-11-11 06:02:03'),
(12, 3, 'username', '/User\\s+\\[([^\\]]+)\\]/', 1, NULL, 1, 'string', '2025-11-15 03:53:16'),
(13, 3, 'source_device', '/from\\s+\\[([^(]+)/', 1, NULL, 1, 'string', '2025-11-15 03:53:16'),
(14, 3, 'user_ip', '/\\(([^)]+)\\)/', 1, NULL, 1, 'string', '2025-11-15 03:53:16'),
(15, 3, 'access_method', '/via\\s+\\[([^\\]]+)\\]/', 1, NULL, 1, 'string', '2025-11-15 03:53:16'),
(16, 3, 'folder_name', '/shared\\s+folder\\s+\\[([^\\]]+)\\]/', 1, NULL, 1, 'string', '2025-11-15 03:53:16'),
(17, 3, 'event_type', '', 1, 'folder_access', 0, 'string', '2025-11-15 03:53:16');

-- --------------------------------------------------------

--
-- Table structure for table `log_mirror`
--

CREATE TABLE `log_mirror` (
  `id` int(11) NOT NULL,
  `collector_id` int(11) NOT NULL,
  `original_log_id` int(11) NOT NULL,
  `received_at` datetime NOT NULL,
  `hostname` varchar(255) DEFAULT NULL,
  `facility` varchar(100) DEFAULT NULL,
  `message` text DEFAULT NULL,
  `port` int(11) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `message_patterns`
--

CREATE TABLE `message_patterns` (
  `id` int(11) NOT NULL,
  `name` varchar(255) NOT NULL,
  `description` text DEFAULT NULL,
  `pattern_regex` varchar(1000) NOT NULL,
  `is_active` tinyint(1) DEFAULT 1,
  `priority` int(11) DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `message_patterns`
--

INSERT INTO `message_patterns` (`id`, `name`, `description`, `pattern_regex`, `is_active`, `priority`, `created_at`, `updated_at`) VALUES
(1, 'File Operations Pattern', 'Matches file/folder operations like upload, download, delete, rename, move, copy, mkdir', '/Event:\\s*(\\w+),\\s*Path:\\s*(.+?)(?:\\s*->\\s*(.+?))?,\\s*File\\/Folder:\\s*(\\w+),\\s*Size:\\s*(.+?),\\s*User:\\s*(.+?),\\s*IP:\\s*(.+)$/', 1, 10, '2025-11-11 06:01:55', '2025-11-11 06:01:55'),
(2, 'System Administrative Pattern', 'Matches system admin messages like user creation, app privileges, etc.', '/^(.+?):#011(.+)$/', 1, 5, '2025-11-11 06:01:55', '2025-11-11 06:01:55'),
(3, 'Access Log Pattern', 'Matches access logs from Synology devices', '/User\\s+\\[([^\\]]+)\\]\\s+from\\s+\\[([^(]+)\\(([^)]+)\\)\\]\\s+via\\s+\\[([^\\]]+)\\]\\s+accessed\\s+shared\\s+folder\\s+\\[([^\\]]+)\\]\\./', 1, 8, '2025-11-15 03:53:16', '2025-11-15 03:53:16');

-- --------------------------------------------------------

--
-- Table structure for table `parsed_logs`
--

CREATE TABLE `parsed_logs` (
  `id` int(11) NOT NULL,
  `log_mirror_id` int(11) NOT NULL,
  `collector_id` int(11) NOT NULL,
  `port` int(11) NOT NULL,
  `pattern_id` int(11) DEFAULT NULL,
  `event_type` varchar(100) DEFAULT NULL,
  `file_path` varchar(1000) DEFAULT NULL,
  `file_folder_type` varchar(50) DEFAULT NULL,
  `file_size` varchar(100) DEFAULT NULL,
  `username` varchar(255) DEFAULT NULL,
  `user_ip` varchar(45) DEFAULT NULL,
  `source_path` varchar(1000) DEFAULT NULL,
  `destination_path` varchar(1000) DEFAULT NULL,
  `additional_data` longtext DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `permission`
--

CREATE TABLE `permission` (
  `id` int(11) NOT NULL,
  `name` varchar(100) NOT NULL,
  `description` varchar(255) DEFAULT NULL,
  `createdAt` timestamp NOT NULL DEFAULT current_timestamp(),
  `updatedAt` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `permission`
--

INSERT INTO `permission` (`id`, `name`, `description`, `createdAt`, `updatedAt`) VALUES
(1, 'view_dashboard', 'View dashboard', '2025-11-10 21:44:53', '2025-11-10 21:44:53'),
(2, 'view_analytics', 'View analytics pages', '2025-11-10 21:44:53', '2025-11-10 21:44:53'),
(3, 'view_reports', 'View reports', '2025-11-10 21:44:53', '2025-11-10 21:44:53'),
(4, 'view_admin', 'View administration section', '2025-11-10 21:44:53', '2025-11-10 21:44:53'),
(5, 'manage_users', 'Manage users (CRUD)', '2025-11-10 21:44:53', '2025-11-10 21:44:53'),
(6, 'manage_permissions', 'Manage user permissions', '2025-11-10 21:44:53', '2025-11-10 21:44:53'),
(7, 'manage_settings', 'Manage system settings', '2025-11-10 21:44:53', '2025-11-10 21:44:53'),
(8, 'view_logs', 'View logs', '2025-11-10 21:44:53', '2025-11-10 21:44:53'),
(9, 'manage_logs', 'Manage logs (delete, modify)', '2025-11-10 21:44:53', '2025-11-10 21:44:53'),
(10, 'view_devices', 'View devices', '2025-11-10 21:44:53', '2025-11-10 21:44:53'),
(11, 'manage_devices', 'Manage devices (CRUD)', '2025-11-10 21:44:53', '2025-11-10 21:44:53'),
(12, 'view_collectors', 'View collectors', '2025-11-10 21:44:53', '2025-11-10 21:44:53'),
(13, 'manage_collectors', 'Manage collectors (CRUD)', '2025-11-10 21:44:53', '2025-11-10 21:44:53'),
(14, 'view_rules', 'View rules', '2025-11-10 21:44:53', '2025-11-10 21:44:53'),
(15, 'manage_rules', 'Manage rules (CRUD)', '2025-11-10 21:44:53', '2025-11-10 21:44:53'),
(16, 'view_patterns', 'View patterns', '2025-11-10 21:44:53', '2025-11-10 21:44:53'),
(17, 'manage_patterns', 'Manage patterns (CRUD)', '2025-11-10 21:44:53', '2025-11-10 21:44:53'),
(18, 'view_filters', 'View filters', '2025-11-10 21:44:53', '2025-11-10 21:44:53'),
(19, 'manage_filters', 'Manage filters (CRUD)', '2025-11-10 21:44:53', '2025-11-10 21:44:53'),
(20, 'view_audit', 'View audit logs', '2025-11-10 21:44:53', '2025-11-10 21:44:53'),
(21, 'manage_audit', 'Manage audit logs', '2025-11-10 21:44:53', '2025-11-10 21:44:53');

-- --------------------------------------------------------

--
-- Table structure for table `session`
--

CREATE TABLE `session` (
  `id` int(11) NOT NULL,
  `adminId` int(11) NOT NULL,
  `sessionToken` varchar(255) NOT NULL,
  `expires` timestamp NOT NULL DEFAULT current_timestamp(),
  `createdAt` timestamp NOT NULL DEFAULT current_timestamp(),
  `updatedAt` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `system_actions`
--

CREATE TABLE `system_actions` (
  `id` int(11) NOT NULL,
  `log_id` int(11) NOT NULL,
  `collector_id` int(11) NOT NULL,
  `action_description` text DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `_prisma_migrations`
--

CREATE TABLE `_prisma_migrations` (
  `id` varchar(36) NOT NULL,
  `checksum` varchar(64) NOT NULL,
  `finished_at` datetime(3) DEFAULT NULL,
  `migration_name` varchar(255) NOT NULL,
  `logs` text DEFAULT NULL,
  `rolled_back_at` datetime(3) DEFAULT NULL,
  `started_at` datetime(3) NOT NULL DEFAULT current_timestamp(3),
  `applied_steps_count` int(10) UNSIGNED NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `_prisma_migrations`
--

INSERT INTO `_prisma_migrations` (`id`, `checksum`, `finished_at`, `migration_name`, `logs`, `rolled_back_at`, `started_at`, `applied_steps_count`) VALUES
('01891d48-ec78-4bef-aada-08d72b3a4fce', '9a7069753fde027e0c0c8ed9c4214535432e7a60eba7433043e172bb5d8c7833', '2025-11-11 03:14:21.692', '20251014060806_make_related_table_optional', NULL, NULL, '2025-11-11 03:14:21.624', 1),
('212241c3-159b-4c8a-836a-c413019fd5b7', '5156e5cbe099ccda9b872351cb1a9a2df9610f6a52e097262c73ee35817c6c23', '2025-11-11 03:14:21.622', '20251013103330_init_permissions_system', NULL, NULL, '2025-11-11 03:14:20.944', 1),
('f6d6b54a-317a-453f-a126-89b0b7dc6d58', '54af64692def0a22461eaf39f1f1188d0d336ec1b3a6c2b12e2f6290e30bde55', '2025-11-11 03:14:48.579', '20251111031448_add_company_relations', NULL, NULL, '2025-11-11 03:14:48.251', 1);

--
-- Indexes for dumped tables
--

--
-- Indexes for table `admin`
--
ALTER TABLE `admin`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `admin_email_key` (`email`),
  ADD KEY `fk_company_id_company_id` (`company_id`);

--
-- Indexes for table `adminpermission`
--
ALTER TABLE `adminpermission`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `AdminPermission_adminId_permissionId_key` (`adminId`,`permissionId`),
  ADD KEY `AdminPermission_permissionId_fkey` (`permissionId`);

--
-- Indexes for table `app_logs`
--
ALTER TABLE `app_logs`
  ADD PRIMARY KEY (`id`),
  ADD KEY `fk_adminID_admin` (`admin_id`);

--
-- Indexes for table `collectors`
--
ALTER TABLE `collectors`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `company`
--
ALTER TABLE `company`
  ADD PRIMARY KEY (`id`),
  ADD KEY `fk_collector_id_collectors_id` (`collector_id`);

--
-- Indexes for table `devices`
--
ALTER TABLE `devices`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_devices_status` (`status`),
  ADD KEY `fk_devices_company_id` (`company_id`),
  ADD KEY `fk_devices_collector_id` (`collector_id`);

--
-- Indexes for table `field_extraction_rules`
--
ALTER TABLE `field_extraction_rules`
  ADD PRIMARY KEY (`id`),
  ADD KEY `field_extraction_rules_ibfk_1` (`pattern_id`);

--
-- Indexes for table `log_mirror`
--
ALTER TABLE `log_mirror`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `unique_collector_log` (`collector_id`,`original_log_id`),
  ADD KEY `idx_log_mirror_collector` (`collector_id`),
  ADD KEY `idx_log_mirror_hostname` (`hostname`),
  ADD KEY `idx_log_mirror_port` (`port`),
  ADD KEY `idx_log_mirror_received_at` (`received_at`);

--
-- Indexes for table `message_patterns`
--
ALTER TABLE `message_patterns`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `parsed_logs`
--
ALTER TABLE `parsed_logs`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `unique_log_pattern` (`log_mirror_id`,`pattern_id`),
  ADD KEY `idx_parsed_logs_event_type` (`event_type`),
  ADD KEY `idx_parsed_logs_username` (`username`),
  ADD KEY `pattern_id` (`pattern_id`),
  ADD KEY `idx_parsed_logs_collector_id` (`collector_id`);

--
-- Indexes for table `permission`
--
ALTER TABLE `permission`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `permission_name_key` (`name`);

--
-- Indexes for table `session`
--
ALTER TABLE `session`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `session_sessionToken_key` (`sessionToken`),
  ADD KEY `session_adminId_fkey` (`adminId`);

--
-- Indexes for table `system_actions`
--
ALTER TABLE `system_actions`
  ADD PRIMARY KEY (`id`),
  ADD KEY `collector_id` (`collector_id`),
  ADD KEY `log_id` (`log_id`);

--
-- Indexes for table `_prisma_migrations`
--
ALTER TABLE `_prisma_migrations`
  ADD PRIMARY KEY (`id`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `admin`
--
ALTER TABLE `admin`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=15;

--
-- AUTO_INCREMENT for table `adminpermission`
--
ALTER TABLE `adminpermission`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=22;

--
-- AUTO_INCREMENT for table `app_logs`
--
ALTER TABLE `app_logs`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=1327;

--
-- AUTO_INCREMENT for table `collectors`
--
ALTER TABLE `collectors`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT for table `company`
--
ALTER TABLE `company`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=15;

--
-- AUTO_INCREMENT for table `devices`
--
ALTER TABLE `devices`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `field_extraction_rules`
--
ALTER TABLE `field_extraction_rules`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=18;

--
-- AUTO_INCREMENT for table `log_mirror`
--
ALTER TABLE `log_mirror`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `message_patterns`
--
ALTER TABLE `message_patterns`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `parsed_logs`
--
ALTER TABLE `parsed_logs`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `permission`
--
ALTER TABLE `permission`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=22;

--
-- AUTO_INCREMENT for table `session`
--
ALTER TABLE `session`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=9;

--
-- AUTO_INCREMENT for table `system_actions`
--
ALTER TABLE `system_actions`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `admin`
--
ALTER TABLE `admin`
  ADD CONSTRAINT `fk_company_id_company_id` FOREIGN KEY (`company_id`) REFERENCES `company` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `adminpermission`
--
ALTER TABLE `adminpermission`
  ADD CONSTRAINT `AdminPermission_adminId_fkey` FOREIGN KEY (`adminId`) REFERENCES `admin` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `AdminPermission_permissionId_fkey` FOREIGN KEY (`permissionId`) REFERENCES `permission` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `app_logs`
--
ALTER TABLE `app_logs`
  ADD CONSTRAINT `fk_adminID_admin` FOREIGN KEY (`admin_id`) REFERENCES `admin` (`id`) ON DELETE SET NULL ON UPDATE CASCADE;

--
-- Constraints for table `company`
--
ALTER TABLE `company`
  ADD CONSTRAINT `fk_collector_id_collectors_id` FOREIGN KEY (`collector_id`) REFERENCES `collectors` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `devices`
--
ALTER TABLE `devices`
  ADD CONSTRAINT `fk_devices_collector_id` FOREIGN KEY (`collector_id`) REFERENCES `collectors` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_devices_company_id` FOREIGN KEY (`company_id`) REFERENCES `company` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `field_extraction_rules`
--
ALTER TABLE `field_extraction_rules`
  ADD CONSTRAINT `field_extraction_rules_ibfk_1` FOREIGN KEY (`pattern_id`) REFERENCES `message_patterns` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `log_mirror`
--
ALTER TABLE `log_mirror`
  ADD CONSTRAINT `fk_collector_logmirror` FOREIGN KEY (`collector_id`) REFERENCES `collectors` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `parsed_logs`
--
ALTER TABLE `parsed_logs`
  ADD CONSTRAINT `parsed_logs_collector_id_fkey` FOREIGN KEY (`collector_id`) REFERENCES `collectors` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `parsed_logs_ibfk_1` FOREIGN KEY (`log_mirror_id`) REFERENCES `log_mirror` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `parsed_logs_ibfk_2` FOREIGN KEY (`pattern_id`) REFERENCES `message_patterns` (`id`) ON DELETE SET NULL;

--
-- Constraints for table `session`
--
ALTER TABLE `session`
  ADD CONSTRAINT `session_adminId_fkey` FOREIGN KEY (`adminId`) REFERENCES `admin` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `system_actions`
--
ALTER TABLE `system_actions`
  ADD CONSTRAINT `system_actions_ibfk_1` FOREIGN KEY (`log_id`) REFERENCES `log_mirror` (`id`) ON DELETE CASCADE ON UPDATE NO ACTION,
  ADD CONSTRAINT `system_actions_ibfk_2` FOREIGN KEY (`collector_id`) REFERENCES `collectors` (`id`) ON DELETE CASCADE ON UPDATE NO ACTION;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
