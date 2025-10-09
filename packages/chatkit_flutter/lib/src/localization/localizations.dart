class ChatKitLocalizations {
  ChatKitLocalizations({
    required this.locale,
    required this.overrides,
    Map<String, Map<String, String>>? bundles,
    this.defaultLocale,
    this.pluralResolver,
  }) : extraBundles = Map<String, Map<String, String>>.unmodifiable({
          for (final entry in (bundles ?? {}).entries)
            _canonicalizeLocale(entry.key):
                Map<String, String>.unmodifiable(entry.value),
        });

  final String? locale;
  final Map<String, String>? overrides;
  final Map<String, Map<String, String>> extraBundles;
  final String? defaultLocale;
  final String Function(String key, num count, {Map<String, Object?> params})?
      pluralResolver;

  static const Map<String, Map<String, String>> _builtInTranslations = {
    'es': {
      'history_title': 'Historial',
      'history_search_hint': 'Buscar conversaciones',
      'history_section_recent': 'Recientes',
      'history_section_archived': 'Archivados',
      'history_section_shared': 'Compartidos',
      'history_pinned_section': 'Fijados',
      'history_empty': 'No hay conversaciones todavía.',
      'history_empty_search':
          'No hay conversaciones que coincidan con tu búsqueda.',
      'history_new_chat': 'Nuevo chat',
      'history_load_more': 'Cargar más',
      'history_refresh': 'Actualizar',
      'history_clear_search': 'Limpiar búsqueda',
      'history_retry': 'Reintentar',
      'history_thread_untitled': 'Conversación sin título',
      'history_status_archived': 'Archivado',
      'history_status_locked': 'Bloqueado',
      'history_status_shared': 'Compartido',
      'composer_add_tag': 'Añadir etiqueta',
      'composer_model_label': 'Modelo',
      'composer_tool_label': 'Herramienta',
      'composer_tool_auto': 'Automático',
      'composer_input_placeholder': 'Escribe al asistente',
      'attachment_limit_reached': 'Límite de adjuntos alcanzado.',
      'attachment_pick_failed': 'No se pudieron cargar los archivos.',
      'attachment_rejected_type': 'Tipo de archivo no compatible.',
      'attachment_rejected_size': 'El archivo supera el límite de tamaño.',
      'attachment_rejected_multiple': 'Algunos archivos fueron omitidos.',
      'attachment_drop_prompt': 'Suelta archivos para adjuntar',
      'attachment_upload_failed': 'Error al subir el adjunto.',
      'attachment_retry_upload': 'Reintentar carga',
      'attachment_remove': 'Eliminar',
      'attachment_uploading': 'Subiendo',
      'attachment_cancel_upload': 'Cancelar carga',
      'entity_picker_title': 'Insertar entidad',
      'entity_picker_search_hint': 'Buscar entidades',
      'entity_picker_no_results': 'Sin resultados',
      'entity_picker_preview': 'Vista previa',
      'entity_picker_close': 'Cerrar',
      'entity_picker_search_button': 'Buscar',
      'auth_expired': 'Sesión expirada',
      'auth_expired_description': 'Renueva tus credenciales para continuar.',
      'auth_expired_dismiss': 'Descartar',
      'feedback_positive': 'Pulgar arriba',
      'feedback_negative': 'Pulgar abajo',
      'retry_response': 'Reintentar respuesta',
      'share_message': 'Compartir mensaje',
      'feedback_sent': 'Comentarios enviados',
      'history_rename': 'Renombrar',
      'history_delete': 'Eliminar',
      'tag_suggestions_loading': 'Buscando entidades...',
      'tag_suggestions_empty': 'Sin coincidencias',
      'share_sheet_title': 'Compartir mensaje',
      'share_option_copy': 'Copiar al portapapeles',
      'share_option_system': 'Compartir...',
      'share_option_cancel': 'Cancelar',
      'share_toast_copied': 'Mensaje copiado al portapapeles.',
      'share_toast_shared': 'Cuadro de compartir abierto.',
      'notice_generic_title': 'Aviso',
      'notice_generic_message': 'Hay una actualización para esta conversación.',
      'notice_rate_limit_title': 'Límite de uso alcanzado',
      'notice_rate_limit_message':
          'Has alcanzado el límite. Espera un momento y vuelve a intentarlo.',
      'composer_disabled_rate_limit':
          'Límite alcanzado. Inténtalo de nuevo pronto.',
      'composer_disabled_auth': 'Sesión expirada. Actualiza para continuar.',
      'rate_limit_retry_in': 'Reintentar en {seconds}s.',
      'banner_dismiss': 'Cerrar',
    },
    'fr': {
      'history_title': 'Historique',
      'history_search_hint': 'Rechercher des conversations',
      'history_section_recent': 'Récentes',
      'history_section_archived': 'Archivées',
      'history_section_shared': 'Partagées',
      'history_pinned_section': 'Épinglées',
      'history_empty': 'Aucune conversation pour le moment.',
      'history_empty_search':
          'Aucune conversation ne correspond à votre recherche.',
      'history_new_chat': 'Nouvelle discussion',
      'history_load_more': 'Charger plus',
      'history_refresh': 'Actualiser',
      'history_clear_search': 'Effacer la recherche',
      'history_retry': 'Réessayer',
      'history_thread_untitled': 'Conversation sans titre',
      'history_status_archived': 'Archivée',
      'history_status_locked': 'Verrouillée',
      'history_status_shared': 'Partagée',
      'composer_add_tag': 'Ajouter une étiquette',
      'composer_model_label': 'Modèle',
      'composer_tool_label': 'Outil',
      'composer_tool_auto': 'Auto',
      'composer_input_placeholder': "Message à l'assistant",
      'attachment_limit_reached': 'Limite de pièces jointes atteinte.',
      'attachment_pick_failed': 'Impossible de charger les fichiers.',
      'attachment_rejected_type': 'Type de fichier non pris en charge.',
      'attachment_rejected_size': 'Le fichier dépasse la taille autorisée.',
      'attachment_rejected_multiple': 'Certains fichiers ont été ignorés.',
      'attachment_drop_prompt': 'Déposez les fichiers à joindre',
      'attachment_upload_failed': 'Échec du téléversement de la pièce jointe.',
      'attachment_retry_upload': 'Réessayer le téléversement',
      'attachment_remove': 'Supprimer',
      'attachment_uploading': 'Téléversement',
      'attachment_cancel_upload': 'Annuler le téléversement',
      'entity_picker_title': 'Insérer une entité',
      'entity_picker_search_hint': 'Rechercher des entités',
      'entity_picker_no_results': 'Aucun résultat',
      'entity_picker_preview': 'Aperçu',
      'entity_picker_close': 'Fermer',
      'entity_picker_search_button': 'Rechercher',
      'auth_expired': 'Session expirée',
      'auth_expired_description':
          'Veuillez renouveler vos identifiants pour continuer.',
      'auth_expired_dismiss': 'Fermer',
      'feedback_positive': 'Pouce en l’air',
      'feedback_negative': 'Pouce en bas',
      'retry_response': 'Relancer la réponse',
      'share_message': 'Partager le message',
      'feedback_sent': 'Retour envoyé',
      'history_rename': 'Renommer',
      'history_delete': 'Supprimer',
      'tag_suggestions_loading': 'Recherche d’entités...',
      'tag_suggestions_empty': 'Aucune correspondance',
      'share_sheet_title': 'Partager le message',
      'share_option_copy': 'Copier dans le presse-papiers',
      'share_option_system': 'Partager...',
      'share_option_cancel': 'Annuler',
      'share_toast_copied': 'Message copié dans le presse-papiers.',
      'share_toast_shared': 'Fenêtre de partage ouverte.',
      'notice_generic_title': 'Avis',
      'notice_generic_message':
          'Une mise à jour est disponible pour cette conversation.',
      'notice_rate_limit_title': 'Limite atteinte',
      'notice_rate_limit_message':
          'Vous avez atteint la limite. Patientez puis réessayez.',
      'composer_disabled_rate_limit': 'Limite atteinte. Réessayez bientôt.',
      'composer_disabled_auth':
          'Authentification expirée. Actualisez pour continuer.',
      'rate_limit_retry_in': 'Nouvel essai dans {seconds}s.',
      'banner_dismiss': 'Fermer',
    },
  };

  static const Map<String, String> _baseStrings = {
    'history_title': 'History',
    'history_search_hint': 'Search conversations',
    'history_section_recent': 'Recent',
    'history_section_archived': 'Archived',
    'history_section_shared': 'Shared',
    'history_pinned_section': 'Pinned',
    'history_empty': 'No conversations yet.',
    'history_empty_search': 'No conversations match your search.',
    'history_new_chat': 'New chat',
    'history_load_more': 'Load more',
    'history_refresh': 'Refresh',
    'history_clear_search': 'Clear search',
    'history_retry': 'Retry',
    'history_thread_untitled': 'Untitled conversation',
    'history_status_archived': 'Archived',
    'history_status_locked': 'Locked',
    'history_status_shared': 'Shared',
    'composer_add_tag': 'Add tag',
    'composer_model_label': 'Model',
    'composer_tool_label': 'Tool',
    'composer_tool_auto': 'Auto',
    'composer_input_placeholder': 'Message the AI',
    'attachment_limit_reached': 'Attachment limit reached.',
    'attachment_pick_failed': 'Unable to add attachment.',
    'attachment_rejected_type': 'Unsupported file type.',
    'attachment_rejected_size': 'File exceeds the size limit.',
    'attachment_rejected_multiple': 'Some files were skipped.',
    'attachment_drop_prompt': 'Drop files to attach',
    'attachment_upload_failed': 'Attachment upload failed.',
    'attachment_retry_upload': 'Retry upload',
    'attachment_remove': 'Remove',
    'attachment_uploading': 'Uploading',
    'attachment_cancel_upload': 'Cancel upload',
    'entity_picker_title': 'Insert entity',
    'entity_picker_search_hint': 'Search entities',
    'entity_picker_no_results': 'No results',
    'entity_picker_preview': 'Preview',
    'entity_picker_close': 'Close',
    'entity_picker_search_button': 'Search',
    'auth_expired': 'Session expired',
    'auth_expired_description':
        'Refresh your credentials to continue using ChatKit.',
    'auth_expired_dismiss': 'Dismiss',
    'feedback_positive': 'Thumbs up',
    'feedback_negative': 'Thumbs down',
    'retry_response': 'Retry response',
    'share_message': 'Share message',
    'feedback_sent': 'Feedback sent',
    'history_rename': 'Rename',
    'history_delete': 'Delete',
    'tag_suggestions_loading': 'Searching entities...',
    'tag_suggestions_empty': 'No matches',
    'share_sheet_title': 'Share message',
    'share_option_copy': 'Copy to clipboard',
    'share_option_system': 'Share...',
    'share_option_cancel': 'Cancel',
    'share_toast_copied': 'Message copied to clipboard.',
    'share_toast_shared': 'Share dialog opened.',
    'notice_generic_title': 'Notice',
    'notice_generic_message': 'There is an update for this conversation.',
    'notice_rate_limit_title': 'Rate limit reached',
    'notice_rate_limit_message':
        'You have reached the rate limit. Please wait and try again.',
    'composer_disabled_rate_limit': 'Rate limit reached. Try again soon.',
    'composer_disabled_auth': 'Authentication expired. Refresh to continue.',
    'rate_limit_retry_in': 'Retry in {seconds}s.',
    'banner_dismiss': 'Dismiss',
  };

  static const Set<String> supportedLocales = {
    'am',
    'ar',
    'bg',
    'bg-BG',
    'bn',
    'bn-BD',
    'bs',
    'bs-BA',
    'ca',
    'ca-ES',
    'cs',
    'cs-CZ',
    'da',
    'da-DK',
    'de',
    'de-DE',
    'el',
    'el-GR',
    'en',
    'es',
    'es-419',
    'es-ES',
    'et',
    'et-EE',
    'fi',
    'fi-FI',
    'fr',
    'fr-CA',
    'fr-FR',
    'gu',
    'gu-IN',
    'hi',
    'hi-IN',
    'hr',
    'hr-HR',
    'hu',
    'hu-HU',
    'hy',
    'hy-AM',
    'id',
    'id-ID',
    'is',
    'is-IS',
    'it',
    'it-IT',
    'ja',
    'ja-JP',
    'ka',
    'ka-GE',
    'kk',
    'kn',
    'kn-IN',
    'ko',
    'ko-KR',
    'lt',
    'lv',
    'lv-LV',
    'mk',
    'mk-MK',
    'ml',
    'mn',
    'mr',
    'mr-IN',
    'ms',
    'ms-MY',
    'my',
    'my-MM',
    'nb',
    'nb-NO',
    'nl',
    'nl-NL',
    'pa',
    'pl',
    'pl-PL',
    'pt',
    'pt-BR',
    'pt-PT',
    'ro',
    'ro-RO',
    'ru',
    'ru-RU',
    'sk',
    'sk-SK',
    'sl',
    'sl-SI',
    'so',
    'so-SO',
    'sq',
    'sq-AL',
    'sr',
    'sr-RS',
    'sv',
    'sv-SE',
    'sw',
    'sw-TZ',
    'ta',
    'ta-IN',
    'te',
    'te-IN',
    'th',
    'th-TH',
    'tl',
    'tr',
    'tr-TR',
    'uk',
    'uk-UA',
    'ur',
    'vi',
    'vi-VN',
    'zh',
    'zh-CN',
    'zh-HK',
    'zh-Hant',
    'zh-TW',
  };

  String t(String key) {
    if (overrides != null && overrides!.containsKey(key)) {
      return overrides![key]!;
    }

    final resolved = _resolveLocale(locale);
    final canonicalDefault =
        defaultLocale != null ? _canonicalizeLocale(defaultLocale!) : null;

    String? lookup(String localeCode) {
      final extra = extraBundles[localeCode];
      if (extra != null && extra.containsKey(key)) {
        return extra[key];
      }
      final builtIn = _builtInTranslations[localeCode];
      if (builtIn != null && builtIn.containsKey(key)) {
        return builtIn[key];
      }
      if (localeCode == 'en' && _baseStrings.containsKey(key)) {
        return _baseStrings[key];
      }
      return null;
    }

    final candidates = <String?>[
      resolved,
      canonicalDefault,
      'en',
    ];

    for (final candidate in candidates.whereType<String>()) {
      final value = lookup(candidate);
      if (value != null) {
        return value;
      }
      final languageCode = candidate.split('-').first;
      if (languageCode != candidate) {
        final languageValue = lookup(languageCode);
        if (languageValue != null) {
          return languageValue;
        }
      }
    }

    return _baseStrings[key] ?? key;
  }

  String format(String key, Map<String, Object?> params) {
    var value = t(key);
    params.forEach((placeholder, rawValue) {
      value = value.replaceAll('{$placeholder}', '${rawValue ?? ''}');
    });
    return value;
  }

  String plural(
    String key,
    num count, {
    Map<String, Object?> params = const {},
  }) {
    if (pluralResolver != null) {
      return pluralResolver!(key, count, params: params);
    }
    final merged = Map<String, Object?>.from(params)..['count'] = count;
    return format(key, merged);
  }

  static String canonicalize(String locale) => _canonicalizeLocale(locale);

  String? _resolveLocale(String? rawLocale) {
    if (rawLocale == null || rawLocale.isEmpty) {
      return null;
    }
    final canonical = _canonicalizeLocale(rawLocale);

    if (extraBundles.containsKey(canonical) ||
        _builtInTranslations.containsKey(canonical)) {
      return canonical;
    }

    final language = canonical.split('-').first;
    if (extraBundles.containsKey(language) ||
        _builtInTranslations.containsKey(language)) {
      return language;
    }

    if (supportedLocales.contains(canonical) ||
        supportedLocales.contains(language)) {
      return canonical;
    }

    return canonical.isEmpty ? null : canonical;
  }

  static String _canonicalizeLocale(String locale) {
    if (locale.isEmpty) {
      return locale;
    }
    final segments = locale.replaceAll('_', '-').split('-');
    if (segments.isEmpty) {
      return locale.toLowerCase();
    }
    final language = segments.first.toLowerCase();
    final rest = segments.skip(1).map((segment) {
      if (segment.length == 2) {
        return segment.toUpperCase();
      }
      return segment.toLowerCase();
    });
    return ([language, ...rest]..removeWhere((part) => part.isEmpty)).join('-');
  }
}
