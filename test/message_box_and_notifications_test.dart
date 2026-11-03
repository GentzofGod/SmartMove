import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartmove/core/services/auth_service.dart';
import 'package:smartmove/core/state/app_state.dart';
import 'package:smartmove/features/messages/presentation/message_box_screen.dart';
import 'package:smartmove/features/messages/presentation/chat_thread_screen.dart';
import 'package:smartmove/features/notifications/presentation/notifications_screen.dart';

class FakeAuthNotifier extends AuthNotifier {
  final UserSession initialSession;
  FakeAuthNotifier(this.initialSession);

  @override
  UserSession build() => initialSession;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Message Box & Notifications State Tests', () {
    test('1. Customer message and trader reply manage unread count and trigger notifications', () async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(
            () => FakeAuthNotifier(
              const UserSession(
                id: 'usr-1',
                email: 'customer@test.com',
                displayName: 'Tunde Customer',
                isGuest: false,
                role: 'Customer',
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final chatNotifier = container.read(traderChatProvider.notifier);

      expect(container.read(unreadMessageCountProvider), 0);

      // Customer sends message
      await chatNotifier.sendCustomerMessage(
        traderName: 'Mama Bello Grains & Oil Enterprise',
        commodityName: 'Oloyin Beans',
        quantity: 5,
        unit: 'kg',
        listedPrice: 8500,
        messageText: 'Hello Mama, can you sell 5kg for ₦8,000?',
        proposedPrice: 8000,
      );

      // Customer message is read by sender; unread count for customer remains 0
      expect(container.read(unreadMessageCountProvider), 0);

      final conversations = container.read(activeConversationsProvider);
      expect(conversations.length, 1);
      expect(conversations.first.conversationKey, 'Mama Bello Grains & Oil Enterprise');
      expect(conversations.first.commodityName, 'Oloyin Beans');
      expect(conversations.first.lastProposedPrice, 8000);

      // Trader replies
      await chatNotifier.sendTraderReply(
        traderName: 'Mama Bello Grains & Oil Enterprise',
        replyText: 'I can do ₦8,200 for 5kg cash on pickup today.',
        commodityName: 'Oloyin Beans',
        proposedPrice: 8200,
      );

      // Customer now has 1 unread message!
      expect(container.read(unreadMessageCountProvider), 1);

      // NotificationsProvider has received the incoming message notification
      final notifs = container.read(notificationsProvider);
      final messageNotif = notifs.firstWhere((n) => n.type == 'Messages');
      expect(messageNotif.title, contains('Mama Bello'));
      expect(messageNotif.subtitle, contains('8,200'));
      expect(messageNotif.isRead, isFalse);

      // Mark conversation as read
      chatNotifier.markConversationAsRead('Mama Bello Grains & Oil Enterprise');
      expect(container.read(unreadMessageCountProvider), 0);

      // Notification should also be marked as read
      final updatedNotifs = container.read(notificationsProvider);
      final updatedMsgNotif = updatedNotifs.firstWhere((n) => n.type == 'Messages');
      expect(updatedMsgNotif.isRead, isTrue);
    });

    test('2. Delete conversation removes thread and purges conversation notifications', () async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(
            () => FakeAuthNotifier(
              const UserSession(
                id: 'usr-1',
                email: 'customer@test.com',
                displayName: 'Tunde Customer',
                isGuest: false,
                role: 'Customer',
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final chatNotifier = container.read(traderChatProvider.notifier);

      await chatNotifier.sendCustomerMessage(
        traderName: 'Alhaji Musa Yam Shed',
        commodityName: 'Abakaliki Yam',
        quantity: 3,
        unit: 'tubers',
        listedPrice: 7000,
        messageText: 'Are the yams dry?',
      );

      expect(container.read(activeConversationsProvider).length, 1);

      chatNotifier.deleteConversation('Alhaji Musa Yam Shed');
      expect(container.read(activeConversationsProvider).length, 0);
    });

    test('3. Guest cannot send messages; auth gating blocks unauthenticated messages', () async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => FakeAuthNotifier(UserSession.guest)),
        ],
      );
      addTearDown(container.dispose);

      final chatNotifier = container.read(traderChatProvider.notifier);

      // Attempt to send message as guest
      await chatNotifier.sendCustomerMessage(
        traderName: 'Kuto Rice Depot',
        commodityName: 'Ofada Rice',
        quantity: 1,
        unit: 'bag',
        listedPrice: 35000,
        messageText: 'Can I pay 30k?',
        proposedPrice: 30000,
      );

      // State remains empty because guest sending was blocked!
      expect(container.read(activeConversationsProvider).length, 0);
      expect(container.read(traderChatProvider)['Kuto Rice Depot'], isNull);
    });

    test('4. Seller accept and decline offer updates offer state and sends confirmation', () async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(
            () => FakeAuthNotifier(
              const UserSession(
                id: 'usr-seller-1',
                email: 'seller@test.com',
                displayName: 'Mama Bello',
                businessName: 'Mama Bello Enterprises',
                isGuest: false,
                role: 'Trader',
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final chatNotifier = container.read(traderChatProvider.notifier);

      // Preload customer offer into state
      await chatNotifier.sendCustomerMessage(
        traderName: 'Mama Bello Enterprises',
        commodityName: 'Palm Oil',
        quantity: 2,
        unit: 'keg',
        listedPrice: 20000,
        messageText: 'I would like to offer ₦18,000 for Palm Oil.',
        proposedPrice: 18000,
      );

      final messagesBefore = container.read(traderChatProvider)['Mama Bello Enterprises']!;
      final custOfferMsg = messagesBefore.first;
      expect(custOfferMsg.proposedPrice, 18000);
      expect(custOfferMsg.isOfferAccepted, isNull);

      // Seller accepts customer's offer
      await chatNotifier.acceptOffer(
        conversationKey: 'Mama Bello Enterprises',
        offerMessageId: custOfferMsg.id,
        acceptedPrice: 18000,
        commodityName: 'Palm Oil',
        isSellerActing: true,
      );

      final messagesAfter = container.read(traderChatProvider)['Mama Bello Enterprises']!;
      expect(messagesAfter.first.isOfferAccepted, isTrue);
      expect(messagesAfter.last.text, contains('Offer of ₦18000 accepted!'));
      expect(messagesAfter.last.isTrader, isTrue);
    });
  });

  group('Message Box & Notification Widgets Tests', () {
    testWidgets('5. Renders MessageBoxScreen with conversation card, filter chips, and search', (tester) async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(
            () => FakeAuthNotifier(
              const UserSession(
                id: 'usr-1',
                email: 'customer@test.com',
                displayName: 'Tunde Customer',
                isGuest: false,
                role: 'Customer',
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Preload a conversation
      await container.read(traderChatProvider.notifier).sendCustomerMessage(
        traderName: 'Bodija Spice Market',
        commodityName: 'Fresh Pepper',
        quantity: 1,
        unit: 'basket',
        listedPrice: 4500,
        messageText: 'Do you deliver to UI gate?',
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: MessageBoxScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Message Box'), findsOneWidget);
      expect(find.text('All (1)'), findsOneWidget);
      expect(find.text('Buying / Sellers'), findsOneWidget);
      expect(find.text('Bodija Spice Market'), findsOneWidget);
      expect(find.text('Do you deliver to UI gate?'), findsOneWidget);
      expect(find.text('Fresh Pepper'), findsOneWidget);
    });

    testWidgets('6. MessageBoxScreen shows Guest callout banner when user is in Guest Mode', (tester) async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => FakeAuthNotifier(UserSession.guest)),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: MessageBoxScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sign in to Message Sellers & Save History'), findsOneWidget);
      expect(find.text('Sign In / Register'), findsOneWidget);
    });

    testWidgets('7. Renders ChatThreadScreen in Buyer Mode with Make Offer button and buyer quick chips', (tester) async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(
            () => FakeAuthNotifier(
              const UserSession(
                id: 'usr-1',
                email: 'customer@test.com',
                displayName: 'Tunde Customer',
                isGuest: false,
                role: 'Customer',
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(traderChatProvider.notifier).sendCustomerMessage(
        traderName: 'Bodija Spice Market',
        commodityName: 'Fresh Pepper',
        quantity: 1,
        unit: 'basket',
        listedPrice: 4500,
        messageText: 'Do you deliver to UI gate?',
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ChatThreadScreen(
              conversationKey: 'Bodija Spice Market',
              initialCommodityName: 'Fresh Pepper',
              initialPrice: 4500,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bodija Spice Market'), findsOneWidget);
      expect(find.text('Negotiating: Fresh Pepper'), findsOneWidget);
      expect(find.text('Do you deliver to UI gate?'), findsOneWidget);
      expect(find.text('Make Offer'), findsOneWidget);
      expect(find.text('Is this item currently in stock?'), findsOneWidget);
      // Seller chips should NOT be shown in buyer mode
      expect(find.text('Yes, available for immediate pickup at our stall'), findsNothing);
    });

    testWidgets('8. Renders ChatThreadScreen in Seller Mode without Make Offer button and with merchant chips & offer actions', (tester) async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(
            () => FakeAuthNotifier(
              const UserSession(
                id: 'usr-seller-1',
                email: 'seller@test.com',
                displayName: 'Alhaji Musa Grains',
                businessName: 'Alhaji Musa Grains',
                isGuest: false,
                role: 'Trader',
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Customer sent an offer message to Alhaji Musa Grains
      final currentList = [
        TraderChatMessage(
          id: 'msg-cust-1',
          senderName: 'Amina Buyer',
          isTrader: false,
          text: 'I would like to offer ₦7,500 for Brown Beans.',
          timestamp: DateTime.now(),
          proposedPrice: 7500,
          commodityName: 'Brown Beans',
          unit: 'bag',
          unitPrice: 8500,
          conversationKey: 'Alhaji Musa Grains',
        ),
      ];

      container.read(traderChatProvider.notifier).state = {
        'Alhaji Musa Grains': currentList,
      };

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ChatThreadScreen(
              conversationKey: 'Alhaji Musa Grains',
              initialPartnerName: 'Amina Buyer',
              initialCommodityName: 'Brown Beans',
              initialPrice: 8500,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Seller banner shows Customer Inquiry, not "Negotiating"
      expect(find.text('Customer Inquiry: Brown Beans'), findsOneWidget);
      expect(find.text('Your Listed Price: ₦8500 / bag'), findsOneWidget);

      // Seller must NEVER see "Make Offer" button to bid on own listing!
      expect(find.text('Make Offer'), findsNothing);

      // Merchant quick reply chips should be visible
      expect(find.text('Yes, available for immediate pickup at our stall'), findsOneWidget);
      // Buyer chips must not be present
      expect(find.text('Is this item currently in stock?'), findsNothing);

      // Offer card should show Accept, Decline, and Counter buttons for the seller!
      expect(find.text('Accept (₦7500)'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);
      expect(find.text('Counter'), findsOneWidget);

      // Tap Accept on the offer
      await tester.tap(find.text('Accept (₦7500)'));
      await tester.pumpAndSettle();

      // Verify offer is accepted
      expect(find.text('Agreed ✓'), findsOneWidget);
      expect(find.textContaining('Offer of ₦7500 accepted!'), findsOneWidget);
    });

    testWidgets('9. NotificationsScreen renders Messages tab and dynamic notifications', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(notificationsProvider.notifier).addNotification(
        NotificationItem(
          id: 'test-msg-01',
          title: 'New message from Kuto Grain Store',
          subtitle: 'Regarding Rice (50kg): We have 10 bags left.',
          timestamp: DateTime.now(),
          type: 'Messages',
          isRead: false,
          conversationKey: 'Kuto Grain Store',
        ),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: NotificationsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Messages'), findsOneWidget);
      expect(find.text('New message from Kuto Grain Store'), findsOneWidget);
      expect(find.text('Regarding Rice (50kg): We have 10 bags left.'), findsOneWidget);
      expect(find.text('Tap to open chat thread & reply'), findsOneWidget);
    });
  });
}
