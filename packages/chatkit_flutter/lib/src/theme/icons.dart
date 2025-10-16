import 'package:flutter/widgets.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Central registry mapping ChatKit icon identifiers to Flutter icon data.
///
/// ChatKit-JS uses a lightweight icon pack with consistent stroke widths.
/// We mirror those metaphors by mapping the same identifiers to the closest
/// matches in the Phosphor icon set (regular weight).
class ChatKitIcons {
  ChatKitIcons._();

  static final Map<String, IconData> _icons = <String, IconData>{
    'agent': PhosphorIconsRegular.robot,
    'analytics': PhosphorIconsRegular.chartLineUp,
    'archive': PhosphorIconsRegular.archive,
    'at': PhosphorIconsRegular.at,
    'atom': PhosphorIconsRegular.atom,
    'attachment': PhosphorIconsRegular.paperclip,
    'audio': PhosphorIconsRegular.musicNotesSimple,
    'batch': PhosphorIconsRegular.stackSimple,
    'bolt': PhosphorIconsRegular.lightning,
    'book-clock': PhosphorIconsRegular.bookBookmark,
    'book-closed': PhosphorIconsRegular.bookBookmark,
    'book-open': PhosphorIconsRegular.bookOpen,
    'browser': PhosphorIconsRegular.globeHemisphereWest,
    'bug': PhosphorIconsRegular.bug,
    'calculator': PhosphorIconsRegular.calculator,
    'calendar': PhosphorIconsRegular.calendarBlank,
    'chart': PhosphorIconsRegular.chartPie,
    'check': PhosphorIconsRegular.check,
    'check-circle': PhosphorIconsRegular.checkCircle,
    'check-circle-filled': PhosphorIconsRegular.checkCircle,
    'chevron-left': PhosphorIconsRegular.caretLeft,
    'chevron-right': PhosphorIconsRegular.caretRight,
    'circle-question': PhosphorIconsRegular.question,
    'compass': PhosphorIconsRegular.compass,
    'confetti': PhosphorIconsRegular.confetti,
    'cube': PhosphorIconsRegular.cube,
    'document': PhosphorIconsRegular.fileText,
    'dots-horizontal': PhosphorIconsRegular.dotsThreeOutline,
    'email': PhosphorIconsRegular.envelope,
    'empty-circle': PhosphorIconsRegular.circle,
    'error': PhosphorIconsRegular.xCircle,
    'file': PhosphorIconsRegular.file,
    'globe': PhosphorIconsRegular.globeHemisphereWest,
    'images': PhosphorIconsRegular.imagesSquare,
    'info': PhosphorIconsRegular.info,
    'keys': PhosphorIconsRegular.key,
    'lab': PhosphorIconsRegular.testTube,
    'lifesaver': PhosphorIconsRegular.lifebuoy,
    'lightbulb': PhosphorIconsRegular.lightbulb,
    'lock': PhosphorIconsRegular.lock,
    'mail': PhosphorIconsRegular.envelope,
    'map-pin': PhosphorIconsRegular.mapPin,
    'maps': PhosphorIconsRegular.mapTrifold,
    'mention': PhosphorIconsRegular.at,
    'name': PhosphorIconsRegular.identificationBadge,
    'notebook': PhosphorIconsRegular.notebook,
    'notebook-pencil': PhosphorIconsRegular.notePencil,
    'page-blank': PhosphorIconsRegular.fileText,
    'paper-plane': PhosphorIconsRegular.paperPlaneRight,
    'paperclip': PhosphorIconsRegular.paperclip,
    'phone': PhosphorIconsRegular.phone,
    'plus': PhosphorIconsRegular.plus,
    'profile': PhosphorIconsRegular.userCircle,
    'profile-card': PhosphorIconsRegular.identificationCard,
    'search': PhosphorIconsRegular.magnifyingGlass,
    'send': PhosphorIconsRegular.paperPlaneRight,
    'settings-slider': PhosphorIconsRegular.slidersHorizontal,
    'sound': PhosphorIconsRegular.musicNotesSimple,
    'sparkle': PhosphorIconsRegular.sparkle,
    'sparkle-double': PhosphorIconsRegular.sparkle,
    'square-code': PhosphorIconsRegular.code,
    'square-image': PhosphorIconsRegular.imageSquare,
    'square-text': PhosphorIconsRegular.textbox,
    'star': PhosphorIconsRegular.star,
    'star-filled': PhosphorIconsRegular.starFour,
    'suitcase': PhosphorIconsRegular.briefcase,
    'user': PhosphorIconsRegular.user,
    'video': PhosphorIconsRegular.videoCamera,
    'warning': PhosphorIconsRegular.warning,
    'wreath': PhosphorIconsRegular.crownSimple,
    'write': PhosphorIconsRegular.penNib,
    'write-alt': PhosphorIconsRegular.pencil,
    'write-alt2': PhosphorIconsRegular.pencilLine,
  };

  static final Map<String, IconData> _headerIcons = <String, IconData>{
    'sidebar-left': PhosphorIconsRegular.sidebar,
    'sidebar-open-left': PhosphorIconsRegular.arrowSquareLeft,
    'sidebar-open-left-alt': PhosphorIconsRegular.arrowCircleLeft,
    'sidebar-collapse-right': PhosphorIconsRegular.arrowFatLineRight,
    'sidebar-right': PhosphorIconsRegular.sidebarSimple,
    'sidebar-open-right': PhosphorIconsRegular.arrowSquareRight,
    'sidebar-open-right-alt': PhosphorIconsRegular.arrowCircleRight,
    'sidebar-collapse-left': PhosphorIconsRegular.arrowFatLineLeft,
    'sidebar-floating-left': PhosphorIconsRegular.sidebar,
    'sidebar-floating-open-left': PhosphorIconsRegular.arrowLineLeft,
    'sidebar-floating-right': PhosphorIconsRegular.sidebarSimple,
    'sidebar-floating-open-right': PhosphorIconsRegular.arrowLineRight,
    'collapse-left': PhosphorIconsRegular.caretCircleLeft,
    'collapse-right': PhosphorIconsRegular.caretCircleRight,
    'open-left': PhosphorIconsRegular.caretCircleLeft,
    'open-right': PhosphorIconsRegular.caretCircleRight,
    'double-chevron-left': PhosphorIconsRegular.caretDoubleLeft,
    'double-chevron-right': PhosphorIconsRegular.caretDoubleRight,
    'back-small': PhosphorIconsRegular.arrowLeft,
    'back-large': PhosphorIconsRegular.arrowCircleLeft,
    'expand-large': PhosphorIconsRegular.arrowsOut,
    'expand-small': PhosphorIconsRegular.arrowsOutSimple,
    'collapse-large': PhosphorIconsRegular.arrowsIn,
    'collapse-small': PhosphorIconsRegular.arrowsInSimple,
    'star': PhosphorIconsRegular.star,
    'star-filled': PhosphorIconsRegular.starFour,
    'chat-temporary': PhosphorIconsRegular.sparkle,
    'settings-cog': PhosphorIconsRegular.gearSix,
    'grid': PhosphorIconsRegular.gridNine,
    'dots-horizontal': PhosphorIconsRegular.dotsThreeOutline,
    'dots-vertical': PhosphorIconsRegular.dotsThreeOutlineVertical,
    'dots-horizontal-circle': PhosphorIconsRegular.dotsThreeCircle,
    'dots-vertical-circle': PhosphorIconsRegular.dotsThreeCircleVertical,
    'menu': PhosphorIconsRegular.list,
    'menu-inverted': PhosphorIconsRegular.list,
    'hamburger': PhosphorIconsRegular.list,
    'compose': PhosphorIconsRegular.penNib,
    'light-mode': PhosphorIconsRegular.sun,
    'dark-mode': PhosphorIconsRegular.moonStars,
    'close': PhosphorIconsRegular.x,
    'home': PhosphorIconsRegular.house,
    'home-alt': PhosphorIconsRegular.houseLine,
    'open-left-alt': PhosphorIconsRegular.caretCircleLeft,
    'open-right-alt': PhosphorIconsRegular.caretCircleRight,
  };

  static IconData? forWidget(String? name) {
    if (name == null || name.isEmpty) {
      return null;
    }
    return _icons[name];
  }

  static IconData? forHeader(String? name) {
    if (name == null || name.isEmpty) {
      return null;
    }
    return _headerIcons[name] ?? _icons[name];
  }
}
