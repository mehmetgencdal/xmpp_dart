import 'dart:async';

import 'package:xmpp_stone/src/Connection.dart';
import 'package:xmpp_stone/src/elements/XmppAttribute.dart';
import 'package:xmpp_stone/src/elements/XmppElement.dart';
import 'package:xmpp_stone/src/elements/forms/FieldElement.dart';
import 'package:xmpp_stone/src/elements/forms/XElement.dart';
import 'package:xmpp_stone/src/elements/stanzas/AbstractStanza.dart';
import 'package:xmpp_stone/src/elements/stanzas/IqStanza.dart';
import 'package:xmpp_stone/src/logger/Log.dart';

class PushNotificationsManager {
  static const TAG = 'PushNotifsManager';

  static Map<Connection, PushNotificationsManager> instances = {};

  static PushNotificationsManager getInstance(Connection connection) {
    var manager = instances[connection];
    if (manager == null) {
      manager = PushNotificationsManager(connection);
      instances[connection] = manager;
    }
    return manager;
  }

  PushNotificationsManager(Connection connection) {
    _connection = connection;
  }

  late Connection _connection;

  Future<IqStanzaResult> queryForEnablePushNotifs(String fcmToken) {
    var completer = Completer<IqStanzaResult>();
    var iqStanza = IqStanza(AbstractStanza.getRandomId(), IqStanzaType.SET);
    iqStanza.addAttribute(XmppAttribute('xmlns', 'jabber:client'));

    var enableElement = XmppElement();
    enableElement.name = 'enable';
    enableElement.addAttribute(XmppAttribute('xmlns', 'urn:xmpp:push:0'));
    enableElement.addAttribute(XmppAttribute('jid', 'pubsub.msg.sashkas.com'));
    enableElement.addAttribute(XmppAttribute('node', fcmToken));

    var x = XElement.build();
    x.setType(FormType.SUBMIT);
    enableElement.addChild(x);
    x.addField(FieldElement.build(
        varAttr: 'FORM_TYPE',
        value: 'http://jabber.org/protocol/pubsub#publish-options'));
    x.addField(FieldElement.build(varAttr: 'device_id', value: fcmToken));
    x.addField(FieldElement.build(varAttr: 'service', value: 'fcm'));
    x.addField(FieldElement.build(varAttr: 'silent', value: 'false'));

    iqStanza.addChild(enableElement);

    Log.d(TAG, 'Sending stanza: ${iqStanza.buildXmlString()}');

    _connection.writeStanza(iqStanza);
    return completer.future;
  }

  Future<IqStanzaResult> queryForDisablePushNotifs(String fcmToken) {
    var completer = Completer<IqStanzaResult>();
    var iqStanza = IqStanza(AbstractStanza.getRandomId(), IqStanzaType.SET);
    iqStanza.addAttribute(XmppAttribute('xmlns', 'jabber:client'));

    var enableElement = XmppElement();
    enableElement.name = 'disable';
    enableElement.addAttribute(XmppAttribute('xmlns', 'urn:xmpp:push:0'));
    enableElement.addAttribute(XmppAttribute('jid', 'pubsub.msg.sashkas.com'));
    enableElement.addAttribute(XmppAttribute('node', fcmToken));

    iqStanza.addChild(enableElement);

    Log.d(TAG, 'Sending stanza: ${iqStanza.toString()}');

    _connection.writeStanza(iqStanza);
    return completer.future;
  }
}
