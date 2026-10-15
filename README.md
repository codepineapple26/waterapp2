# Water Delivery

A simple Flutter app for water delivery ordering with PocketBase authentication and an order dashboard that lets users see their own order delivery status.

## Features

- Email/password login using PocketBase
- Account creation flow
- Dashboard with user order list
- Order detail screen with status timeline
- Demo order creation for testing
- PocketBase integration with user-specific filtering

## PocketBase setup

1. Start PocketBase locally or on your remote server.
2. Create a `users` collection with email/password authentication enabled.
3. Create an `orders` collection with the following fields:
   - `user_id` (text / relation-like string field for the logged-in user)
   - `customer_name` (text)
   - `phone` (text)
   - `address` (text)
   - `quantity` (number)
   - `notes` (text, optional)
   - `status` (text, default: `New`)
   - `total` (number)
4. Update the PocketBase URL in `lib/services/pocketbase_service.dart` if needed.

## Run the app

```bash
flutter pub get
flutter run
```

## Notes

- The app currently uses the PocketBase server URL ``.
- If your emulator/device uses a different host, update the constant in `lib/services/pocketbase_service.dart`.
- For Android emulator, use `10.0.2.2` instead of `localhost`.

## Example login flow

- Create an account or sign in with an existing user.
- After login, the dashboard loads only the orders linked to the logged-in `user_id`.
- Tap any order to view the delivery details and status timeline.

## Production notes

- Use HTTPS in production.
- Configure PocketBase CORS for mobile or web app domains.
- Keep the PocketBase host in a secure config instead of hardcoding it directly.

## Useful PocketBase commands

```bash
pocketbase serve
```

For admin setup: use the PocketBase dashboard or admin CLI to enable auth for the `users` collection.

