.pragma library

// AI > Code tasks: defaults of new tasks, queue, notifications, review and
// the look of the task board (ai.tasks.*, pushed to the backend through
// tasks.configure by TasksService). Entry format: see modules/settings/AGENTS.md.

var AGENTS = [
    {
        "value": "claude",
        "label": "prefs.ai.tasks.agent_claude",
        "icon": "robot"
    },
    {
        "value": "codex",
        "label": "prefs.ai.tasks.agent_codex",
        "icon": "terminal"
    },
    {
        "value": "opencode",
        "label": "prefs.ai.tasks.agent_opencode",
        "icon": "code"
    }
];

var category = {
    "id": "ai-code",
    "icon": "kanban",
    "title": "prefs.ai.tasks",
    "description": "prefs.ai.tasks.desc",
    "keywords": "ai code tasks agents board worktree review accept merge squash best of plan queue parallel claude codex opencode",
    "sections": [
        {
            "id": "new_tasks",
            "title": "prefs.ai.tasks.new",
            "entries": [
                {
                    "key": "ai.tasks.defaultAgents",
                    "type": "multiselect",
                    "label": "prefs.ai.tasks.default_agents",
                    "description": "prefs.ai.tasks.default_agents.desc",
                    "keywords": "agent default best of n parallel claude codex opencode",
                    "options": AGENTS
                },
                {
                    "key": "ai.tasks.planFirst",
                    "type": "toggle",
                    "label": "prefs.ai.tasks.plan_first",
                    "description": "prefs.ai.tasks.plan_first.desc",
                    "keywords": "plan first steps approve"
                },
                {
                    "key": "ai.tasks.inPlace",
                    "type": "toggle",
                    "label": "prefs.ai.tasks.in_place",
                    "description": "prefs.ai.tasks.in_place.desc",
                    "keywords": "worktree current branch checkout in place"
                }
            ]
        },
        {
            "id": "queue",
            "title": "prefs.ai.tasks.queue",
            "entries": [
                {
                    "key": "ai.tasks.maxParallel",
                    "type": "number",
                    "label": "prefs.ai.tasks.max_parallel",
                    "description": "prefs.ai.tasks.max_parallel.desc",
                    "keywords": "parallel concurrent slots queue",
                    "min": 1,
                    "max": 8
                },
                {
                    "key": "ai.tasks.fallbackAgent",
                    "type": "selector",
                    "label": "prefs.ai.tasks.fallback",
                    "description": "prefs.ai.tasks.fallback.desc",
                    "keywords": "fallback limit usage rate agent",
                    "options": [
                        {
                            "value": "",
                            "label": "prefs.ai.tasks.fallback_none",
                            "icon": "hourglass"
                        }
                    ].concat(AGENTS)
                }
            ]
        },
        {
            "id": "review",
            "title": "prefs.ai.tasks.review",
            "entries": [
                {
                    "key": "ai.tasks.mergeMode",
                    "type": "selector",
                    "label": "prefs.ai.tasks.merge_mode",
                    "description": "prefs.ai.tasks.merge_mode.desc",
                    "keywords": "merge squash commit accept",
                    "options": [
                        {
                            "value": "squash",
                            "label": "prefs.ai.tasks.merge_squash",
                            "icon": "stack"
                        },
                        {
                            "value": "merge",
                            "label": "prefs.ai.tasks.merge_merge",
                            "icon": "gitBranch"
                        }
                    ]
                },
                {
                    "key": "ai.tasks.autoOpenReview",
                    "type": "toggle",
                    "label": "prefs.ai.tasks.auto_open_review",
                    "description": "prefs.ai.tasks.auto_open_review.desc",
                    "keywords": "review open automatically finished"
                },
                {
                    "key": "ai.tasks.confirmAccept",
                    "type": "toggle",
                    "label": "prefs.ai.tasks.confirm_accept",
                    "description": "prefs.ai.tasks.confirm_accept.desc",
                    "keywords": "confirm accept commit"
                },
                {
                    "key": "ai.tasks.confirmDiscard",
                    "type": "toggle",
                    "label": "prefs.ai.tasks.confirm_discard",
                    "description": "prefs.ai.tasks.confirm_discard.desc",
                    "keywords": "confirm discard delete worktree"
                },
                {
                    "key": "ai.tasks.commitWithAi",
                    "type": "toggle",
                    "label": "prefs.ai.tasks.commit_ai",
                    "description": "prefs.ai.tasks.commit_ai.desc",
                    "keywords": "commit message ai write git"
                }
            ]
        },
        {
            "id": "notifications",
            "title": "prefs.ai.tasks.notifications",
            "entries": [
                {
                    "key": "ai.tasks.notifications",
                    "type": "toggle",
                    "label": "prefs.ai.tasks.notify",
                    "description": "prefs.ai.tasks.notify.desc",
                    "keywords": "notification desktop alert"
                },
                {
                    "key": "ai.tasks.notifyEvents",
                    "type": "multiselect",
                    "label": "prefs.ai.tasks.notify_events",
                    "description": "prefs.ai.tasks.notify_events.desc",
                    "keywords": "notification permission plan review failed limit",
                    "enabledWhen": {
                        "key": "ai.tasks.notifications",
                        "equals": true
                    },
                    "options": [
                        {
                            "value": "permission",
                            "label": "prefs.ai.tasks.event_permission",
                            "icon": "hand"
                        },
                        {
                            "value": "plan",
                            "label": "prefs.ai.tasks.event_plan",
                            "icon": "listChecks"
                        },
                        {
                            "value": "review",
                            "label": "prefs.ai.tasks.event_review",
                            "icon": "eye"
                        },
                        {
                            "value": "failed",
                            "label": "prefs.ai.tasks.event_failed",
                            "icon": "xCircle"
                        },
                        {
                            "value": "limit",
                            "label": "prefs.ai.tasks.event_limit",
                            "icon": "hourglass"
                        }
                    ]
                }
            ]
        },
        {
            "id": "board",
            "title": "prefs.ai.tasks.board",
            "entries": [
                {
                    "key": "ai.tasks.boardLayout",
                    "type": "selector",
                    "label": "prefs.ai.tasks.layout",
                    "description": "prefs.ai.tasks.layout.desc",
                    "keywords": "board columns list kanban layout",
                    "options": [
                        {
                            "value": "auto",
                            "label": "prefs.ai.tasks.layout_auto",
                            "icon": "sparkle"
                        },
                        {
                            "value": "columns",
                            "label": "prefs.ai.tasks.layout_columns",
                            "icon": "kanban"
                        },
                        {
                            "value": "list",
                            "label": "prefs.ai.tasks.layout_list",
                            "icon": "list"
                        }
                    ]
                },
                {
                    "key": "ai.tasks.showCosts",
                    "type": "toggle",
                    "label": "prefs.ai.tasks.show_costs",
                    "description": "prefs.ai.tasks.show_costs.desc",
                    "keywords": "cost tokens price card"
                },
                {
                    "key": "ai.tasks.showElapsed",
                    "type": "toggle",
                    "label": "prefs.ai.tasks.show_elapsed",
                    "description": "prefs.ai.tasks.show_elapsed.desc",
                    "keywords": "time elapsed duration card"
                },
                {
                    "key": "ai.tasks.showBranch",
                    "type": "toggle",
                    "label": "prefs.ai.tasks.show_branch",
                    "description": "prefs.ai.tasks.show_branch.desc",
                    "keywords": "branch worktree badge card"
                },
                {
                    "key": "ai.tasks.doneLimit",
                    "type": "number",
                    "label": "prefs.ai.tasks.done_limit",
                    "description": "prefs.ai.tasks.done_limit.desc",
                    "keywords": "done finished history count",
                    "min": 0,
                    "max": 200,
                    "step": 5,
                    "specialValues": [
                        {
                            "value": 0,
                            "label": "prefs.ai.tasks.done_all"
                        }
                    ]
                }
            ]
        }
    ]
};
