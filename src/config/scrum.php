<?php

return [
    /*
    |--------------------------------------------------------------------------
    | Scrum Board Configuration
    |--------------------------------------------------------------------------
    |
    | Configuration for the Scrum/agile project management board
    |
    */

    // Story point scale (Fibonacci sequence commonly used)
    'story_points' => [
        'scale' => [0, 1, 2, 3, 5, 8, 13, 21],
        'allow_custom' => env('SCRUM_CUSTOM_POINTS', false),
        'default' => 3,
    ],

    // Sprint configuration
    'sprint' => [
        // Default sprint duration in days
        'default_duration' => (int) env('SCRUM_SPRINT_DURATION', 14),

        // Minimum and maximum sprint duration
        'min_duration' => (int) env('SCRUM_MIN_DURATION', 7),
        'max_duration' => (int) env('SCRUM_MAX_DURATION', 30),

        // Sprint capacity calculation (hours per day per person)
        'default_capacity_hours' => (int) env('SCRUM_DEFAULT_CAPACITY', 6),

        // Velocity calculation sprints (number of sprints to average)
        'velocity_sprints' => (int) env('SCRUM_VELOCITY_SPRINTS', 3),
    ],

    // Task categories/types
    'task_categories' => [
        'feature',
        'bug',
        'refactor',
        'documentation',
        'testing',
        'design',
        'infrastructure',
        'research',
    ],

    // Task priority levels
    'priorities' => [
        'low' => [
            'label' => 'Low',
            'color' => '#6c757d',
            'weight' => 1,
        ],
        'medium' => [
            'label' => 'Medium',
            'color' => '#17a2b8',
            'weight' => 2,
        ],
        'high' => [
            'label' => 'High',
            'color' => '#ffc107',
            'weight' => 3,
        ],
        'critical' => [
            'label' => 'Critical',
            'color' => '#dc3545',
            'weight' => 4,
        ],
    ],

    // Bug severity levels
    'bug_severity' => [
        'trivial' => [
            'label' => 'Trivial',
            'color' => '#28a745',
            'response_time_hours' => 168, // 1 week
        ],
        'low' => [
            'label' => 'Low',
            'color' => '#6c757d',
            'response_time_hours' => 120, // 5 days
        ],
        'medium' => [
            'label' => 'Medium',
            'color' => '#17a2b8',
            'response_time_hours' => 72, // 3 days
        ],
        'high' => [
            'label' => 'High',
            'color' => '#ffc107',
            'response_time_hours' => 24, // 1 day
        ],
        'critical' => [
            'label' => 'Critical',
            'color' => '#fd7e14',
            'response_time_hours' => 8, // 8 hours
        ],
        'blocker' => [
            'label' => 'Blocker',
            'color' => '#dc3545',
            'response_time_hours' => 4, // 4 hours
        ],
    ],

    // Task status workflow
    'task_status' => [
        'backlog' => [
            'label' => 'Backlog',
            'description' => 'Not yet planned for a sprint',
        ],
        'todo' => [
            'label' => 'To Do',
            'description' => 'Planned but not started',
        ],
        'in_progress' => [
            'label' => 'In Progress',
            'description' => 'Currently being worked on',
        ],
        'review' => [
            'label' => 'In Review',
            'description' => 'Ready for code review',
        ],
        'done' => [
            'label' => 'Done',
            'description' => 'Completed and verified',
        ],
    ],

    // Story status workflow
    'story_status' => [
        'backlog' => [
            'label' => 'Backlog',
            'description' => 'Product backlog item',
        ],
        'refined' => [
            'label' => 'Refined',
            'description' => 'Refinement completed',
        ],
        'planned' => [
            'label' => 'Planned',
            'description' => 'Planned for a sprint',
        ],
        'in_progress' => [
            'label' => 'In Progress',
            'description' => 'Story in development',
        ],
        'testing' => [
            'label' => 'Testing',
            'description' => 'Under testing/QA',
        ],
        'done' => [
            'label' => 'Done',
            'description' => 'Completed and accepted',
        ],
    ],

    // Bug status workflow
    'bug_status' => [
        'open' => [
            'label' => 'Open',
            'description' => 'Bug reported',
        ],
        'assigned' => [
            'label' => 'Assigned',
            'description' => 'Assigned to developer',
        ],
        'in_progress' => [
            'label' => 'In Progress',
            'description' => 'Being fixed',
        ],
        'resolved' => [
            'label' => 'Resolved',
            'description' => 'Fix completed, awaiting verification',
        ],
        'verified' => [
            'label' => 'Verified',
            'description' => 'Fix verified by QA',
        ],
        'closed' => [
            'label' => 'Closed',
            'description' => 'Bug closed',
        ],
    ],

    // Sprint status workflow
    'sprint_status' => [
        'planning' => [
            'label' => 'Planning',
            'description' => 'Sprint planning phase',
        ],
        'active' => [
            'label' => 'Active',
            'description' => 'Sprint in progress',
        ],
        'review' => [
            'label' => 'Review',
            'description' => 'Sprint review phase',
        ],
        'completed' => [
            'label' => 'Completed',
            'description' => 'Sprint completed',
        ],
    ],

    // Sprint member roles
    'roles' => [
        'scrum_master' => [
            'label' => 'Scrum Master',
            'description' => 'Facilitates the Scrum process',
            'permissions' => ['manage_sprint', 'assign_tasks', 'update_sprint'],
        ],
        'product_owner' => [
            'label' => 'Product Owner',
            'description' => 'Owns the product backlog',
            'permissions' => ['manage_backlog', 'prioritize', 'accept_work'],
        ],
        'developer' => [
            'label' => 'Developer',
            'description' => 'Team member working on tasks',
            'permissions' => ['work_on_tasks', 'update_status'],
        ],
        'tester' => [
            'label' => 'QA Tester',
            'description' => 'Tests and verifies work',
            'permissions' => ['test_tasks', 'report_bugs', 'verify_stories'],
        ],
        'designer' => [
            'label' => 'Designer',
            'description' => 'Creates designs and UI',
            'permissions' => ['create_designs', 'update_ui'],
        ],
        'observer' => [
            'label' => 'Observer',
            'description' => 'Read-only access',
            'permissions' => ['view'],
        ],
    ],

    // Business value levels
    'business_value' => [
        0 => 'None',
        10 => 'Low',
        30 => 'Medium',
        60 => 'High',
        100 => 'Critical',
    ],

    // Complexity levels
    'complexity' => [
        1 => 'Trivial',
        2 => 'Simple',
        3 => 'Moderate',
        5 => 'Complex',
        8 => 'Very Complex',
        10 => 'Extremely Complex',
    ],

    // Definition of Done checklist
    'definition_of_done' => [
        'code_reviewed' => 'Code reviewed and approved',
        'tests_written' => 'Unit tests written and passing',
        'tests_passed' => 'QA tests passed',
        'documented' => 'Documentation updated',
        'deployed' => 'Deployed to staging',
        'demoed' => 'Demoed to team',
    ],

    // WIP (Work In Progress) limits
    'wip_limits' => [
        'in_progress' => 3,
        'review' => 2,
    ],

    // Time tracking settings
    'time_tracking' => [
        'enabled' => env('SCRUM_TIME_TRACKING', true),
        'require_estimate' => env('SCRUM_REQUIRE_ESTIMATE', false),
        'track_actual' => env('SCRUM_TRACK_ACTUAL', true),
    ],

    // Notifications
    'notifications' => [
        'task_assigned' => env('SCRUM_NOTIFY_TASK_ASSIGNED', true),
        'task_completed' => env('SCRUM_NOTIFY_TASK_COMPLETED', true),
        'sprint_started' => env('SCRUM_NOTIFY_SPRINT_STARTED', true),
        'sprint_completed' => env('SCRUM_NOTIFY_SPRINT_COMPLETED', true),
        'bug_reported' => env('SCRUM_NOTIFY_BUG_REPORTED', true),
        'bug_assigned' => env('SCRUM_NOTIFY_BUG_ASSIGNED', true),
    ],

    // Chart and report settings
    'charts' => [
        'burndown' => [
            'enabled' => true,
            'show_ideal_line' => true,
            'show_actual_line' => true,
        ],
        'velocity' => [
            'enabled' => true,
            'default_sprints' => 5,
        ],
        'cumulative_flow' => [
            'enabled' => true,
        ],
    ],

    // Epic settings
    'epics' => [
        'enabled' => true,
        'require_color' => false,
        'auto_group' => true,
    ],

    // Labels/tags
    'labels' => [
        'enabled' => true,
        'suggested' => [
            'frontend',
            'backend',
            'database',
            'api',
            'ui',
            'performance',
            'security',
            'documentation',
        ],
    ],

    // Attachment settings
    'attachments' => [
        'enabled' => true,
        'max_files' => 10,
        'max_size_mb' => 10,
        'allowed_types' => ['jpg', 'jpeg', 'png', 'gif', 'pdf', 'txt', 'doc', 'docx'],
    ],

    // Archive settings
    'archive' => [
        'auto_archive_after_days' => 90,
        'keep_completed_sprints' => 10,
    ],

    // Integration settings
    'integrations' => [
        'github' => [
            'enabled' => env('SCRUM_GITHUB_ENABLED', false),
            'auto_link' => env('SCRUM_GITHUB_AUTO_LINK', false),
            'close_on_merge' => env('SCRUM_GITHUB_CLOSE_ON_MERGE', false),
        ],
        'slack' => [
            'enabled' => env('SCRUM_SLACK_ENABLED', false),
            'webhook_url' => env('SCRUM_SLACK_WEBHOOK'),
        ],
        'jira' => [
            'enabled' => env('SCRUM_JIRA_ENABLED', false),
            'api_url' => env('SCRUM_JIRA_API_URL'),
            'project_key' => env('SCRUM_JIRA_PROJECT_KEY'),
        ],
    ],
];
