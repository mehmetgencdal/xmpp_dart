import 'package:xml/xml.dart' as xml;
import 'package:xmpp_stone/src/data/Jid.dart';
import 'package:xmpp_stone/src/elements/XmppAttribute.dart';
import 'package:xmpp_stone/src/elements/XmppElement.dart';
import 'package:xmpp_stone/src/elements/forms/FieldElement.dart';
import 'package:xmpp_stone/src/elements/forms/XElement.dart';
import 'package:xmpp_stone/src/elements/stanzas/AbstractStanza.dart';
import 'package:xmpp_stone/src/elements/stanzas/MessageStanza.dart';
import 'package:xmpp_stone/src/elements/stanzas/PresenceStanza.dart';
import 'package:xmpp_stone/src/features/servicediscovery/Feature.dart';
import 'package:xmpp_stone/src/features/servicediscovery/Identity.dart';
import 'package:xmpp_stone/src/parser/IqParser.dart';

import '../logger/Log.dart';

class StanzaParser {
  static const TAG = 'StanzaParser';

  //TODO: Improve this!
  static AbstractStanza? parseStanza(xml.XmlElement element) {
    AbstractStanza? stanza;
    var id = element.getAttribute('id');
    if (id == null) {
      Log.d(TAG, 'No id found for stanza');
    }

    if (element.name.local == 'iq') {
      stanza = IqParser.parseIqStanza(id, element);
    } else if (element.name.local == 'message') {
      if (isMAMStanza(element)) {
        // print('MAM STANZA FOUND ${element.toString()}');
        stanza = _parseMAMStanza(element);
      } else {
        stanza = _parseMessageStanza(id, element);
      }
    } else if (element.name.local == 'presence') {
      stanza = _parsePresenceStanza(id, element);
    }
    if (!isMAMStanza(element)) {
      var fromString = element.getAttribute('from');
      if (fromString != null) {
        var from = Jid.fromFullJid(fromString);
        stanza!.fromJid = from;
      }
      var toString = element.getAttribute('to');
      if (toString != null) {
        var to = Jid.fromFullJid(toString);
        stanza!.toJid = to;
      }
    }
    element.attributes.forEach((xmlAttribute) {
      stanza!.addAttribute(
          XmppAttribute(xmlAttribute.name.local, xmlAttribute.value));
    });
    element.children.forEach((child) {
      if (child is xml.XmlElement) stanza!.addChild(parseElement(child));
    });
    return stanza;
  }

  static bool isMAMStanza(xml.XmlElement element) {
    return element.name.local == 'message' &&
        element.findElements('result', namespace: 'urn:xmpp:mam:2').isNotEmpty;
  }

  static MessageStanza? _parseMAMStanza(xml.XmlElement mamStanza) {
    final resultElements = mamStanza.findElements('result').first;
    // Extract elements from the MAM stanza
    final forwardedElements = resultElements.findElements('forwarded');
    if (forwardedElements.isEmpty) {
      print("No 'forwarded' element found in MAM stanza.");
      return null;
    }

    final forwardedElement = forwardedElements.first;

    final delayElements = forwardedElement.findElements('delay');
    if (delayElements.isEmpty) {
      print("No 'delay' element found in 'forwarded' element.");
      return null;
    }

    final delayElement = delayElements.first;
    final timestamp = delayElement.getAttribute('stamp');

    final messageElements = forwardedElement.findElements('message');
    if (messageElements.isEmpty) {
      print("No 'message' element found in 'forwarded' element.");
      return null;
    }

    final messageElement = messageElements.first;

    final fromAttribute = messageElement.getAttribute('from');
    if (fromAttribute == null) {
      print("'from' attribute not found in 'message' element.");
      return null;
    }

    final toAttribute = messageElement.getAttribute('to');
    if (toAttribute == null) {
      print("'to' attribute not found in 'message' element.");
      return null;
    }

    final idAttribute = messageElement.getAttribute('id');
    // final typeAttribute = messageElement.getAttribute('type');

    final bodyElements = messageElement.findElements('body');
    if (bodyElements.isEmpty) {
      print("No 'body' element found in 'message' element.");
      return null;
    }
    final bodyElement = bodyElements.first;
    final body = bodyElement.innerText;

    final from = Jid.fromFullJid(fromAttribute);
    final to = Jid.fromFullJid(toAttribute);
    final id = idAttribute ?? '';

    // Create a new message stanza
    final messageStanza = MessageStanza(id, MessageStanzaType.CHAT);

    // Set the properties of the message stanza
    messageStanza.fromJid = from;
    messageStanza.toJid = to;
    // messageStanza.type = MessageStanzaType.CHAT;
    messageStanza.id = id;
    messageStanza.body = body;
    messageStanza.timestamp = timestamp;

    return messageStanza;
  }

  static MessageStanza _parseMessageStanza(String? id, xml.XmlElement element) {
    var typeString = element.getAttribute('type');
    MessageStanzaType? type;
    if (typeString == null) {
      Log.w(TAG, 'No type found for message stanza');
    } else {
      switch (typeString) {
        case 'chat':
          type = MessageStanzaType.CHAT;
          break;
        case 'error':
          type = MessageStanzaType.ERROR;
          break;
        case 'groupchat':
          type = MessageStanzaType.GROUPCHAT;
          break;
        case 'headline':
          type = MessageStanzaType.HEADLINE;
          break;
        case 'normal':
          type = MessageStanzaType.NORMAL;
          break;
      }
    }
    var stanza = MessageStanza(id, type);

    return stanza;
  }

  static PresenceStanza _parsePresenceStanza(
      String? id, xml.XmlElement element) {
    var presenceStanza = PresenceStanza();
    presenceStanza.id = id;
    return presenceStanza;
  }

  static XmppElement parseElement(xml.XmlElement xmlElement) {
    XmppElement xmppElement;
    var parentName = (xmlElement.parent as xml.XmlElement?)?.name.local ?? '';
    var name = xmlElement.name.local;
    if (parentName == 'query' && name == 'identity') {
      xmppElement = Identity();
    } else if (parentName == 'query' && name == 'feature') {
      xmppElement = Feature();
    } else if (name == 'x') {
      xmppElement = XElement();
    } else if (name == 'field') {
      xmppElement = FieldElement();
    } else {
      xmppElement = XmppElement();
    }
    xmppElement.name = xmlElement.name.local;
    xmlElement.attributes.forEach((xmlAttribute) {
      xmppElement.addAttribute(
          XmppAttribute(xmlAttribute.name.local, xmlAttribute.value));
    });
    xmlElement.children.forEach((xmlChild) {
      if (xmlChild is xml.XmlElement) {
        xmppElement.addChild(parseElement(xmlChild));
      } else if (xmlChild is xml.XmlText) {
        xmppElement.textValue = xmlChild.value;
      }
    });
    return xmppElement;
  }
}
