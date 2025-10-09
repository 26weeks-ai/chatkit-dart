import 'dart:convert';

/// JSON fixture that mirrors a streamed assistant response with mixed content
/// (text deltas, annotations, widget streaming updates, and a final completion).
const String streamingFixtureJson = '''
[
  {
    "type": "thread.item.added",
    "item": {
      "id": "msg_assistant",
      "thread_id": "thread_weekly",
      "created_at": "2024-06-12T17:00:00Z",
      "type": "assistant_message",
      "role": "assistant",
      "content": [],
      "attachments": [],
      "metadata": {
        "stage": "streaming"
      },
      "widget": {
        "id": "root_card",
        "type": "card",
        "size": "md",
        "padding": "lg",
        "background": "#F8FAFC",
        "children": [
          {
            "id": "header_row",
            "type": "row",
            "gap": "md",
            "align": "center",
            "justify": "space_between",
            "children": [
              {
                "id": "title_text",
                "type": "text",
                "value": "Coach recap",
                "size": "lg",
                "weight": "semibold"
              },
              {
                "id": "status_badge",
                "type": "badge",
                "label": "Live",
                "variant": "success"
              }
            ]
          },
          {
            "id": "stream_text",
            "type": "text",
            "value": "",
            "streaming": true,
            "size": "sm"
          },
          {
            "id": "cta_group",
            "type": "button.group",
            "gap": "sm",
            "children": [
              {
                "id": "primary_cta",
                "type": "button",
                "label": "Open report",
                "variant": "solid",
                "action": {
                  "type": "open_report"
                }
              },
              {
                "id": "secondary_cta",
                "type": "button",
                "label": "Dismiss",
                "variant": "ghost",
                "action": {
                  "type": "dismiss"
                }
              }
            ]
          }
        ]
      }
    }
  },
  {
    "type": "thread.item.updated",
    "item_id": "msg_assistant",
    "update": {
      "type": "assistant_message.content_part.added",
      "content_index": 0,
      "content": {
        "type": "output_text",
        "text": "",
        "annotations": []
      }
    }
  },
  {
    "type": "thread.item.updated",
    "item_id": "msg_assistant",
    "update": {
      "type": "assistant_message.content_part.text_delta",
      "content_index": 0,
      "delta": "Hello athlete! "
    }
  },
  {
    "type": "thread.item.updated",
    "item_id": "msg_assistant",
    "update": {
      "type": "assistant_message.content_part.annotation_added",
      "content_index": 0,
      "annotation": {
        "type": "file_reference",
        "file_id": "file_weekly_plan",
        "text": "Weekly Plan.pdf"
      }
    }
  },
  {
    "type": "thread.item.updated",
    "item_id": "msg_assistant",
    "update": {
      "type": "assistant_message.content_part.text_delta",
      "content_index": 0,
      "delta": "Here is your summary."
    }
  },
  {
    "type": "thread.item.updated",
    "item_id": "msg_assistant",
    "update": {
      "type": "widget.streaming_text.value_delta",
      "component_id": "stream_text",
      "delta": "Focus: Recovery mobility\\n",
      "done": false
    }
  },
  {
    "type": "thread.item.updated",
    "item_id": "msg_assistant",
    "update": {
      "type": "widget.streaming_text.value_delta",
      "component_id": "stream_text",
      "delta": "Next: Long run Saturday",
      "done": true
    }
  },
  {
    "type": "thread.item.updated",
    "item_id": "msg_assistant",
    "update": {
      "type": "widget.component.updated",
      "component_id": "secondary_cta",
      "component": {
        "id": "secondary_cta",
        "type": "button",
        "label": "View history",
        "variant": "outline",
        "action": {
          "type": "view_history"
        }
      }
    }
  },
  {
    "type": "progress_update",
    "icon": "check",
    "text": "Summaries compiled"
  },
  {
    "type": "thread.item.done",
    "item": {
      "id": "msg_assistant",
      "thread_id": "thread_weekly",
      "created_at": "2024-06-12T17:00:00Z",
      "type": "assistant_message",
      "role": "assistant",
      "attachments": [],
      "metadata": {
        "stage": "complete"
      },
      "content": [
        {
          "type": "output_text",
          "text": "Hello athlete! Here is your summary.",
          "annotations": [
            {
              "type": "file_reference",
              "file_id": "file_weekly_plan",
              "text": "Weekly Plan.pdf"
            }
          ]
        }
      ],
      "widget": {
        "id": "root_card",
        "type": "card",
        "size": "md",
        "padding": "lg",
        "background": "#F8FAFC",
        "children": [
          {
            "id": "header_row",
            "type": "row",
            "gap": "md",
            "align": "center",
            "justify": "space_between",
            "children": [
              {
                "id": "title_text",
                "type": "text",
                "value": "Coach recap",
                "size": "lg",
                "weight": "semibold"
              },
              {
                "id": "status_badge",
                "type": "badge",
                "label": "Live",
                "variant": "success"
              }
            ]
          },
          {
            "id": "stream_text",
            "type": "text",
            "value": "Focus: Recovery mobility\\nNext: Long run Saturday",
            "streaming": false,
            "size": "sm"
          },
          {
            "id": "cta_group",
            "type": "button.group",
            "gap": "sm",
            "children": [
              {
                "id": "primary_cta",
                "type": "button",
                "label": "Open report",
                "variant": "solid",
                "action": {
                  "type": "open_report"
                }
              },
              {
                "id": "secondary_cta",
                "type": "button",
                "label": "View history",
                "variant": "outline",
                "action": {
                  "type": "view_history"
                }
              }
            ]
          }
        ]
      }
    }
  }
]
''';

/// Returns a parsed, mutable copy of the streaming fixture events.
List<Map<String, Object?>> streamingFixtureEvents() {
  final decoded = jsonDecode(streamingFixtureJson) as List;
  return decoded
      .map(
        (entry) => Map<String, Object?>.from(
          (entry as Map).cast<String, Object?>(),
        ),
      )
      .toList(growable: false);
}

/// Produces a raw SSE payload string that includes retry hints and heartbeat
/// messages used to exercise the transport client.
String streamingFixtureAsSse() {
  final buffer = StringBuffer();
  var id = 0;
  for (final event in streamingFixtureEvents()) {
    id += 1;
    buffer.writeln('id: $id');
    buffer.writeln('event: ${event['type']}');
    buffer.writeln('data: ${jsonEncode(event)}');
    if (id == 1) {
      buffer.writeln('retry: 2500');
    }
    buffer.writeln();
  }
  buffer.writeln('event: heartbeat');
  buffer.writeln('data: ping');
  buffer.writeln();
  buffer.writeln('retry: 1500');
  buffer.writeln();
  return buffer.toString();
}

const Map<String, Object?> clientToolCallItemJson = {
  'id': 'tool_call_weather',
  'thread_id': 'thread_tool',
  'created_at': '2024-06-12T17:05:00Z',
  'type': 'client_tool_call',
  'role': 'assistant',
  'content': <Map<String, Object?>>[],
  'attachments': <Map<String, Object?>>[],
  'metadata': <String, Object?>{},
  'name': 'browser',
  'call_id': 'call_weather',
  'arguments': {
    'location': 'Valencia',
    'units': 'metric',
  },
};

List<Map<String, Object?>> clientToolFixtureEvents() {
  final added = Map<String, Object?>.from(clientToolCallItemJson);
  final done = Map<String, Object?>.from(clientToolCallItemJson)
    ..['status'] = {'type': 'completed'};
  return [
    {
      'type': 'thread.item.added',
      'item': added,
    },
    {
      'type': 'thread.item.done',
      'item': done,
    },
  ];
}

const Map<String, Object?> workflowItemJson = {
  'id': 'workflow_item',
  'thread_id': 'thread_workflow',
  'created_at': '2024-06-12T17:10:00Z',
  'type': 'assistant_message',
  'role': 'assistant',
  'content': [
    {
      'type': 'output_text',
      'text': 'Building weekly plan…',
    },
  ],
  'attachments': <Map<String, Object?>>[],
  'metadata': <String, Object?>{},
  'workflow': {
    'tasks': <Map<String, Object?>>[],
  },
};

List<Map<String, Object?>> workflowFixtureEvents() {
  return [
    {
      'type': 'thread.item.added',
      'item': Map<String, Object?>.from(workflowItemJson),
    },
    {
      'type': 'thread.item.updated',
      'item_id': 'workflow_item',
      'update': {
        'type': 'workflow.task.added',
        'task_index': 0,
        'task': {
          'id': 'task_collect_inputs',
          'title': 'Collect athlete inputs',
          'status': 'pending',
        },
      },
    },
    {
      'type': 'thread.item.updated',
      'item_id': 'workflow_item',
      'update': {
        'type': 'workflow.task.updated',
        'task_index': 0,
        'task': {
          'id': 'task_collect_inputs',
          'title': 'Collect athlete inputs',
          'status': 'complete',
          'notes': 'All questionnaires answered.',
        },
      },
    },
  ];
}
