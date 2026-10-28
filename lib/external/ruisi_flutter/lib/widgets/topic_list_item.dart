// Copyright 2026 BenderBlog Rodriguez and Contributors.
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:watermeter/repository/demo_data/demo_data_mode.dart';

import '../constants/urls.dart';
import '../models/topic.dart';

/// 帖子列表项
class TopicListItem extends StatelessWidget {
  final Topic topic;
  final VoidCallback? onTap;

  const TopicListItem({super.key, required this.topic, this.onTap});

  /// 演示数据头像
  Widget _avatar(BuildContext context) {
    if (DemoDataMode.enabled) {
      final initial = topic.author.isEmpty ? "?" : topic.author.substring(0, 1);
      return CircleAvatar(
        radius: 12,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Text(
          initial,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: CachedNetworkImage(
        imageUrl: Urls.getAvaterUrl(topic.authorId),
        width: 24,
        height: 24,
        fit: BoxFit.cover,
        placeholder: (_, _) => const Icon(Icons.person),
        errorWidget: (_, _, _) => const Icon(Icons.person),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      title: Text(topic.title),
      leading: _avatar(context),
      subtitle: Padding(
        padding: EdgeInsetsGeometry.symmetric(vertical: 4),
        child: Wrap(
          spacing: 4.0,
          runSpacing: 4.0,
          children: [
            if (topic.isStick)
              _TopicInfoWidget(
                needErrorColor: true,
                text: FlutterI18n.translate(
                  context,
                  'ruisi.topic_list_item.sticky',
                ),
              ),

            if (topic.categoryName != null && topic.categoryName!.isNotEmpty)
              _TopicInfoWidget(text: topic.categoryName!),

            _TopicInfoWidget(icon: Icons.person, text: topic.author),

            if (topic.lastReplyTime != null)
              _TopicInfoWidget(
                icon: Icons.access_time,
                text: topic.lastReplyTime!,
              ),

            _TopicInfoWidget(
              icon: Icons.chat_bubble_outline,
              text: '${topic.replies}',
            ),

            _TopicInfoWidget(
              icon: Icons.remove_red_eye,
              text: '${topic.views}',
            ),
          ],
        ),
      ),
    );
  }
}

class _TopicInfoWidget extends StatelessWidget {
  final bool needErrorColor;
  final IconData? icon;
  final String text;
  const _TopicInfoWidget({
    this.needErrorColor = false,
    this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: needErrorColor
            ? theme.colorScheme.error
            : theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Padding(
              padding: EdgeInsetsGeometry.only(right: 2),
              child: Icon(icon, size: 14),
            ),
          Text(
            text,
            style: theme.textTheme.labelSmall?.copyWith(
              color: needErrorColor
                  ? theme.colorScheme.onError
                  : theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}
