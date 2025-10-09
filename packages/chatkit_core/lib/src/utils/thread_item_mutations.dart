import '../models/thread.dart';
import 'json.dart';

ThreadItem applyThreadItemUpdate(
  ThreadItem item,
  Map<String, Object?> update,
) {
  final type = update['type'] as String? ?? '';
  switch (type) {
    case 'assistant_message.content_part.added':
      return _applyAssistantContentAdded(item, update);
    case 'assistant_message.content_part.text_delta':
      return _applyAssistantTextDelta(item, update);
    case 'assistant_message.content_part.annotation_added':
      return _applyAssistantAnnotationAdded(item, update);
    case 'assistant_message.content_part.done':
      return _applyAssistantContentDone(item, update);
    case 'widget.streaming_text.value_delta':
      return _applyWidgetStreamingDelta(item, update);
    case 'widget.component.updated':
      return _applyWidgetComponentUpdated(item, update);
    case 'widget.root.updated':
      return _applyWidgetRootUpdated(item, update);
    case 'workflow.task.added':
      return _applyWorkflowTaskAdded(item, update);
    case 'workflow.task.updated':
      return _applyWorkflowTaskUpdated(item, update);
    default:
      return item;
  }
}

ThreadItem _applyAssistantContentAdded(
  ThreadItem item,
  Map<String, Object?> update,
) {
  final contentIndex = update['content_index'] as int? ?? item.content.length;
  final content = castMap(update['content']);
  final newContent = List<Map<String, Object?>>.from(item.content);
  if (contentIndex >= newContent.length) {
    newContent.add(content);
  } else {
    newContent.insert(contentIndex, content);
  }
  return item.copyWith(content: newContent);
}

ThreadItem _applyAssistantTextDelta(
  ThreadItem item,
  Map<String, Object?> update,
) {
  final contentIndex = update['content_index'] as int? ?? 0;
  final delta = update['delta'] as String? ?? '';
  final newContent = List<Map<String, Object?>>.from(item.content);
  if (contentIndex < 0 || contentIndex >= newContent.length) {
    return item;
  }
  final entry = Map<String, Object?>.from(newContent[contentIndex]);
  final text = (entry['text'] as String? ?? '') + delta;
  entry['text'] = text;
  newContent[contentIndex] = entry;
  return item.copyWith(content: newContent);
}

ThreadItem _applyAssistantAnnotationAdded(
  ThreadItem item,
  Map<String, Object?> update,
) {
  final contentIndex = update['content_index'] as int? ?? 0;
  final annotation = castMap(update['annotation']);
  final newContent = List<Map<String, Object?>>.from(item.content);
  if (contentIndex < 0 || contentIndex >= newContent.length) {
    return item;
  }
  final entry = Map<String, Object?>.from(newContent[contentIndex]);
  final annotations = List<Map<String, Object?>>.from(
    (entry['annotations'] as List?)?.map(castMap) ?? const [],
  );
  annotations.add(annotation);
  entry['annotations'] = annotations;
  newContent[contentIndex] = entry;
  return item.copyWith(content: newContent);
}

ThreadItem _applyAssistantContentDone(
  ThreadItem item,
  Map<String, Object?> update,
) {
  final contentIndex = update['content_index'] as int? ?? 0;
  final content = castMap(update['content']);
  final newContent = List<Map<String, Object?>>.from(item.content);
  if (contentIndex < 0 || contentIndex >= newContent.length) {
    if (contentIndex == newContent.length) {
      newContent.add(content);
    } else {
      return item;
    }
  } else {
    newContent[contentIndex] = content;
  }
  return item.copyWith(content: newContent);
}

ThreadItem _applyWidgetStreamingDelta(
  ThreadItem item,
  Map<String, Object?> update,
) {
  final componentId = update['component_id'] as String?;
  final delta = update['delta'] as String? ?? '';
  if (componentId == null) {
    return item;
  }
  final widget = castMap(item.raw['widget']);
  final updatedWidget =
      _updateWidgetComponent(widget, componentId, (component) {
    final newComponent = Map<String, Object?>.from(component);
    final value = (newComponent['value'] as String? ?? '') + delta;
    newComponent['value'] = value;
    if (update['done'] is bool) {
      newComponent['streaming'] = !(update['done'] as bool);
    }
    return newComponent;
  });
  return item.copyWith(raw: {
    ...item.raw,
    'widget': updatedWidget,
  });
}

ThreadItem _applyWidgetComponentUpdated(
  ThreadItem item,
  Map<String, Object?> update,
) {
  final componentId = update['component_id'] as String?;
  if (componentId == null) {
    return item;
  }
  final component = castMap(update['component']);
  final widget = castMap(item.raw['widget']);
  final updatedWidget =
      _updateWidgetComponent(widget, componentId, (_) => component);
  return item.copyWith(raw: {
    ...item.raw,
    'widget': updatedWidget,
  });
}

ThreadItem _applyWidgetRootUpdated(
  ThreadItem item,
  Map<String, Object?> update,
) {
  final widget = castMap(update['widget']);
  return item.copyWith(raw: {
    ...item.raw,
    'widget': widget,
  });
}

ThreadItem _applyWorkflowTaskAdded(
  ThreadItem item,
  Map<String, Object?> update,
) {
  final taskIndex = update['task_index'] as int? ?? 0;
  final task = castMap(update['task']);
  final workflow = castMap(item.raw['workflow']);
  final tasks = List<Map<String, Object?>>.from(
    (workflow['tasks'] as List?)?.map(castMap) ?? const [],
  );
  if (taskIndex >= tasks.length) {
    tasks.add(task);
  } else {
    tasks.insert(taskIndex, task);
  }
  final newWorkflow = {
    ...workflow,
    'tasks': tasks,
  };
  return item.copyWith(raw: {
    ...item.raw,
    'workflow': newWorkflow,
  });
}

ThreadItem _applyWorkflowTaskUpdated(
  ThreadItem item,
  Map<String, Object?> update,
) {
  final taskIndex = update['task_index'] as int? ?? 0;
  final task = castMap(update['task']);
  final workflow = castMap(item.raw['workflow']);
  final tasks = List<Map<String, Object?>>.from(
    (workflow['tasks'] as List?)?.map(castMap) ?? const [],
  );
  if (taskIndex < 0 || taskIndex >= tasks.length) {
    return item;
  }
  tasks[taskIndex] = task;
  final newWorkflow = {
    ...workflow,
    'tasks': tasks,
  };
  return item.copyWith(raw: {
    ...item.raw,
    'workflow': newWorkflow,
  });
}

Map<String, Object?> _updateWidgetComponent(
  Map<String, Object?> widget,
  String componentId,
  Map<String, Object?> Function(Map<String, Object?> component) transform,
) {
  Map<String, Object?> visit(Map<String, Object?> node) {
    if (node['id'] == componentId) {
      return transform(node);
    }
    final children = node['children'];
    if (children is List) {
      final updatedChildren = <Map<String, Object?>>[];
      for (final child in children) {
        final childMap = castMap(child);
        updatedChildren.add(visit(childMap));
      }
      return {
        ...node,
        'children': updatedChildren,
      };
    }
    return node;
  }

  return visit(widget);
}
