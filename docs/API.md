# SewSmart API contract

Draft 4. The API is built in `backend/` and both apps call it. There are no riders: the tailor delivers the order and marks it `delivered`. Draft 3, 11 October 2026. The 36 admin panel endpoints and the 68 mobile endpoints added since 7 October 2026 are designed in full. The 29 mobile endpoints that the app already named are listed, and the request and response details of most of them still have to be written. Draft 3 adds the 18 endpoints behind the screens built on 11 October 2026 (3.18 to 3.24).

This file is the agreement between the Flutter apps and the backend. Every endpoint below has a matching `// METHOD /path` comment above the service method that calls it. To change an endpoint, change this file, the backend and that comment in the same pull request.

## Contents

1. [Conventions](#1-conventions)
2. [Values](#2-values)
3. [Mobile app endpoints](#3-mobile-app-endpoints)
4. [Admin panel endpoints](#4-admin-panel-endpoints)
5. [Not designed yet](#5-not-designed-yet)
6. [Decisions to confirm](#6-decisions-to-confirm)

## 1. Conventions

| Topic | Rule |
| --- | --- |
| Base path | `/api`. Admin routes sit under `/api/admin`. |
| Format | JSON request and response bodies. An endpoint that takes a file uses `multipart/form-data` and says so. |
| Field names | snake_case, for example `created_at`, `is_verified`, `total_orders`. The mobile models already read these names. |
| IDs | Every object has a string `id`. Do not return MongoDB's `_id`. Orders, payments and disputes show their ID to people, so give them short readable IDs such as `ORD-1042`. |
| Dates | ISO 8601 in UTC, for example `2024-06-01T09:30:00.000Z`. |
| Money | Plain numbers in PKR. No currency symbol and no separators. |
| Values | Status, role and method values are lower camelCase and listed in section 2. The mobile app parses them with `values.byName`, which throws on any other spelling. |
| Lists | A JSON array, newest first unless the endpoint says otherwise. Filters are optional query parameters. Leave one out to get everything. |
| Authentication | `Authorization: Bearer <token>` on every route except login, register, OTP and forgot password. Admin routes need an admin token. |
| Success | `200` with the object or array, `201` when something is created, `204` with no body when there is nothing to return, such as delete and logout. An action such as approve, cancel or resolve returns the updated object. |
| Errors | The status code plus `{ "message": "..." }`. `400` invalid input, `401` missing or expired token or wrong credentials, `403` wrong role, `404` not found, `409` not allowed in the current state. `429` too many attempts: the login routes allow 8 wrong passwords per account and address in 15 minutes, and the routes that send a code or an email allow 5 per 15 minutes. The message says how long to wait. |

## 2. Values

The API always sends and accepts the values in the middle column. The admin panel shows them as labels. Its mock data holds the labels today, so the conversion belongs in the admin models' `fromJson` when the screens are connected. The mobile screens also hold labels such as Bank Account and Cash on Delivery, and convert the same way.

| Field | API values | Admin panel label |
| --- | --- | --- |
| `role` | `customer`, `tailor` | Same word, capitalised |
| Account `status` | `active`, `suspended` | Same word, capitalised |
| Verification `status` | `pending`, `approved`, `rejected` | Same word, capitalised |
| Order `status` | `pending`, `accepted`, `rejected`, `inProgress`, `qualityCheck`, `readyForDelivery`, `delivered`, `completed`, `cancelled` | Four tabs, see the next table |
| Payment `status` | `pending`, `completed`, `refunded` | `pending` is Processing, `completed` is Paid, `refunded` is Refunded. |
| Payment `method` | `wallet` | Not shown: every order is paid from the wallet |
| Dispute `status` | `open`, `resolved` | Same word, capitalised |
| Dispute `resolution` | `refund`, `warning`, `dismiss` | Same word, capitalised |
| Design `status`, also a portfolio sample | `active`, `flagged` | Same word, capitalised |
| Review `status` | `published`, `flagged` | Same word, capitalised |
| Content report `status` | `pending`, `resolved` | Same word, capitalised |
| Content report `action` | `remove`, `warn`, `dismiss` | Remove Content, Issue Warning, Dismiss Report |
| Report `range` | `today`, `thisWeek`, `thisMonth`, `custom` | Today, This Week, This Month, Custom |
| Saved payment method `type` | `jazzCash`, `easyPaisa`, `bank`, `card` | Not shown in the admin panel |
| Payout account `type` | `jazzCash`, `easyPaisa`, `bank` | Not shown in the admin panel |
| Withdrawal `status` | `pending`, `paid`, `failed` | Not shown in the admin panel |
| Message `type` | `text`, `image`, `document` | Not shown in the admin panel |
| Stream `status` | `live`, `ended` | Not shown in the admin panel |
| Measurement `unit` | `cm`, `in` | Not shown in the admin panel |
| Notification `type` | `order`, `payment`, `chat`, `delivery`, `new_order`, `message`, `verified`, `issue_resolved` | Not shown in the admin panel |

Notification types are the one exception to the camelCase rule. The three notification screens already compare these exact strings to pick an icon, and an unknown type gets a default icon. The customer screen expects `chat` for a new message and the tailor screen expects `message`.

The admin Orders screen has four tabs for the nine order statuses. The grouping follows how the customer app already splits active and finished orders.

| Admin tab | Order statuses |
| --- | --- |
| Pending | `pending` |
| In Progress | `accepted`, `inProgress`, `qualityCheck`, `readyForDelivery` |
| Completed | `delivered`, `completed` |
| Cancelled | `rejected`, `cancelled` |

## 3. Mobile app endpoints

The mobile app needs 97 endpoints. The service files already named 29 of them as TODO comments. 50 more were added on 7 October 2026 for the features that had no endpoint at all, and 18 on 11 October 2026 for the screens that were missing. Each added one is a mock-backed method with its endpoint as a TODO comment. The screens built on 11 October 2026 call their methods. Most older screens still read mock data directly, and connecting them is part of the backend work.

A user keeps one ID across the app. The tailor `T001` in `/api/tailors/T001` is the user `T001`.

### 3.1 Endpoints the app already named

Their methods and paths are fixed by the app. Response fields are fixed only where a model has `fromJson`. Their request and response details still have to be written here.

#### Auth

Service: `lib/core/services/auth_service.dart`

| Endpoint | Service method | Purpose |
| --- | --- | --- |
| `POST /api/auth/login` | `login` | Sign in with email and password. Returns a token and the user. |
| `POST /api/auth/register` | `register` | Create a customer or tailor account. |
| `POST /api/auth/send-otp` | `sendOtp` | Send a 4-digit code to a phone number. |
| `POST /api/auth/verify-otp` | `verifyOtp` | Check the code. |
| `POST /api/auth/forgot-password` | `forgotPassword` | Email a password reset link. |
| `POST /api/auth/logout` | `logout` | End the session. |

#### Customer

Service: `lib/modules/customer/services/customer_service.dart`

| Endpoint | Service method | Purpose |
| --- | --- | --- |
| `GET /api/tailors?category=&city=&rating=&price=&search=` | `getTailors` | Search and filter tailors. |
| `GET /api/tailors/:id` | `getTailorById` | One tailor's public profile. |
| `GET /api/orders` | `getMyOrders` | The customer's orders. |
| `POST /api/orders` | `placeOrder` | Place an order. |
| `PUT /api/orders/:id/delivery-schedule` | `setDeliverySchedule` | Choose a delivery date and time slot. |
| `POST /api/payments` | `makePayment` | Pay for an order from the wallet. |
| `POST /api/reviews` | `submitReview` | Rate a tailor. |
| `GET /api/notifications` | `getNotifications` | The user's notifications. |
| `GET /api/garments/pricing` | `getGarmentPricing` | Garment price list. |

#### Tailor

Service: `lib/modules/tailor/services/tailor_service.dart`

| Endpoint | Service method | Purpose |
| --- | --- | --- |
| `GET /api/orders?status=` | `getOrders` | The tailor's orders, optionally by status. |
| `PUT /api/orders/:id/accept` | `acceptOrder` | Accept a pending order. |
| `PUT /api/orders/:id/reject` | `rejectOrder` | Reject a pending order. |
| `PUT /api/orders/:id/status` | `updateOrderStatus` | Move an order forward: `inProgress`, `qualityCheck`, `readyForDelivery`, then `delivered` once the customer has it. |
| `POST /api/orders/:id/delivery-request` | `sendDeliveryRequest` | Ask the customer to schedule delivery. |
| `GET /api/tailors/:id/earnings` | `getEarnings` | Earnings totals and monthly chart. |

### 3.2 Endpoints added by this contract

Three services are new and sit in `lib/core/services/` because more than one role uses them: `NotificationService`, `ChatService` and `PayoutService`.

| Endpoint | Service method | Screen that needs it |
| --- | --- | --- |
| `POST /api/auth/reset-password` | `AuthService.resetPassword` | Reset password |
| `GET /api/users/me` | `AuthService.getProfile` | Customer profile, tailor profile |
| `PUT /api/users/me` | `AuthService.updateProfile` | Customer profile, tailor profile |
| `PUT /api/tailors/:id` | `TailorService.updateProfile` | Tailor profile |
| `GET /api/tailors/:id/portfolio` | `TailorService.getPortfolio` | Tailor profile |
| `POST /api/tailors/:id/portfolio` | `TailorService.addPortfolioSample` | Tailor profile |
| `DELETE /api/tailors/:id/portfolio/:itemId` | `TailorService.removePortfolioSample` | Tailor profile |
| `GET /api/tailors/:id/garments` | `TailorService.getGarments`, `CustomerService.getTailorGarments` | Tailor profile, place order, tailor public profile |
| `POST /api/tailors/:id/garments` | `TailorService.addGarment` | Tailor profile |
| `PUT /api/tailors/:id/garments/:garmentId` | `TailorService.updateGarment` | Tailor profile |
| `DELETE /api/tailors/:id/garments/:garmentId` | `TailorService.removeGarment` | Tailor profile |
| `GET /api/tailors/:id/reviews` | `CustomerService.getTailorReviews` | Tailor public profile |
| `GET /api/categories` | `CustomerService.getCategories` | Browse tailors |
| `POST /api/coupons/validate` | `CustomerService.validateCoupon` | Place order |
| `GET /api/measurements` | `CustomerService.getMeasurements` | Measure |
| `PUT /api/measurements` | `CustomerService.saveMeasurements` | Measure |
| `GET /api/payment-methods` | `CustomerService.getPaymentMethods` | Payment methods |
| `POST /api/payment-methods` | `CustomerService.addPaymentMethod` | Payment methods |
| `PUT /api/payment-methods/:id/default` | `CustomerService.setDefaultPaymentMethod` | Payment methods |
| `DELETE /api/payment-methods/:id` | `CustomerService.removePaymentMethod` | Payment methods |
| `GET /api/wishlist` | `CustomerService.getWishlist` | Customer profile, saved designs, AI recommendations |
| `POST /api/wishlist` | `CustomerService.addToWishlist` | AI recommendations |
| `DELETE /api/wishlist/:designId` | `CustomerService.removeFromWishlist` | Saved designs |
| `POST /api/searches` | `CustomerService.recordSearch` | AI recommendations, browse tailors |
| `GET /api/searches` | `CustomerService.getMySearches` | AI recommendations |
| `GET /api/searches/trending` | `CustomerService.getTrendingSearches` | AI recommendations |
| `GET /api/ai/recommendations` | `CustomerService.getRecommendations` | AI recommendations |
| `POST /api/ai/designs` | `CustomerService.generateDesigns` | AI design studio |
| `POST /api/ai/designs/:id/send` | `CustomerService.sendDesignToTailor` | AI design studio |
| `POST /api/ai/try-on` | `CustomerService.generateTryOn` | Virtual try-on |
| `PUT /api/ai/try-on/:id/save` | `CustomerService.saveTryOn` | Virtual try-on |
| `GET /api/payout-accounts` | `PayoutService.getPayoutAccounts` | Tailor payment |
| `POST /api/payout-accounts` | `PayoutService.addPayoutAccount` | Tailor payment |
| `PUT /api/payout-accounts/:id/default` | `PayoutService.setDefaultPayoutAccount` | Tailor payment |
| `DELETE /api/payout-accounts/:id` | `PayoutService.removePayoutAccount` | Tailor payment |
| `GET /api/withdrawals` | `PayoutService.getWithdrawals` | Tailor payment |
| `POST /api/withdrawals` | `PayoutService.requestWithdrawal` | Tailor earnings, live stream |
| `GET /api/conversations` | `ChatService.getConversations` | Chat tab for customers and tailors |
| `GET /api/orders/:id/messages` | `ChatService.getMessages` | Chat |
| `POST /api/orders/:id/messages` | `ChatService.sendMessage` | Chat |
| `PUT /api/orders/:id/messages/read` | `ChatService.markMessagesRead` | Chat |
| `PUT /api/notifications/:id/read` | `NotificationService.markRead` | Tailor notifications |
| `PUT /api/notifications/read-all` | `NotificationService.markAllRead` | All three notification screens |
| `POST /api/streams` | `TailorService.startStream` | Live stream |
| `GET /api/streams/:id` | `TailorService.getStream` | Live stream |
| `GET /api/streams/:id/messages` | `TailorService.getStreamMessages` | Live stream |
| `PUT /api/streams/:id/pin` | `TailorService.pinStreamItem` | Live stream |
| `PUT /api/streams/:id/end` | `TailorService.endStream` | Live stream |
| `POST /api/streams/:id/video-token` | `LiveVideo` | Live stream (tailor and viewer) |

### 3.3 Account

**`GET /api/users/me`**

Returns the signed-in user, the same object that login returns.

```json
{
  "id": "C001",
  "name": "Ayesha Khan",
  "email": "ayesha@email.com",
  "phone": "0300-1234567",
  "role": "customer",
  "is_verified": true,
  "avatar": null,
  "city": "Lahore",
  "created_at": "2025-01-15T00:00:00.000Z"
}
```

**`PUT /api/users/me`**

Send any of `name`, `phone` and `city`. Returns the updated user. `400` when `name` is empty and `409` when the phone number belongs to another account. The edit dialog has only name and phone today.

```json
{
  "name": "Ayesha Khan",
  "phone": "0300-1234567"
}
```

**`POST /api/auth/reset-password`**

```json
{
  "token": "token-from-the-reset-link",
  "new_password": "new-password"
}
```

Returns `204`. `400` when the token is wrong or older than 15 minutes, or the password is shorter than 4 characters, which is the rule the register screen applies. The app does not open links yet, so the email must also show the token as a code. The customer types it on the Reset Password screen, which opens from Enter Reset Code after the email is sent. When the app can open links, the link passes the token to the same screen and the code box is hidden.

### 3.4 Tailor profile, portfolio and price list

Only the tailor who owns the profile may change it. Any other token gets `403`.

**`PUT /api/tailors/:id`**

Send any of these fields. Returns the tailor object from `GET /api/tailors/:id`, which now also carries `experience_years`.

```json
{
  "name": "Sana's Couture",
  "phone": "0302-3456789",
  "city": "Lahore",
  "experience_years": 8,
  "bio": "Expert in bridal and formal wear with 8+ years of experience."
}
```

`name` is the business name. `phone` is stored on the user account.

**`GET /api/tailors/:id/portfolio`**

```json
[
  {
    "id": "PF001",
    "tailor_id": "T001",
    "title": "Royal Bridal Lehenga",
    "image_url": "https://example.com/uploads/portfolio/pf001.jpg",
    "status": "active",
    "created_at": "2026-05-01T00:00:00.000Z"
  }
]
```

These are the items the admin panel lists as designs. The `portfolio` field inside the tailor object stays a plain array of the `image_url` values, because `TailorModel` reads it that way.

**`POST /api/tailors/:id/portfolio`**

Multipart form data with `image` as the file and an optional `title`. Returns `201` with the new item.

**`DELETE /api/tailors/:id/portfolio/:itemId`**

Returns `204`.

**`GET /api/tailors/:id/garments`**

The tailor's own price list. Anyone signed in may read it.

```json
[
  {
    "id": "G001",
    "garment": "Shalwar Kameez",
    "price": 1800,
    "estimated_time": "3-4 days"
  }
]
```

**`POST /api/tailors/:id/garments`**

```json
{
  "garment": "Abaya",
  "price": 2800,
  "estimated_time": "4-5 days"
}
```

Returns `201` with the new item.

**`PUT /api/tailors/:id/garments/:garmentId`**

Send any of the three fields. Returns the updated item.

**`DELETE /api/tailors/:id/garments/:garmentId`**

Returns `204`.

**`GET /api/tailors/:id/reviews`**

The tailor's published reviews, newest first.

```json
[
  {
    "id": "REV001",
    "customer_id": "C001",
    "tailor_id": "T001",
    "customer_name": "Ayesha K.",
    "comment": "Amazing bridal work! Exactly as I imagined.",
    "rating": 5,
    "created_at": "2026-09-23T10:00:00.000Z"
  }
]
```

### 3.5 Coupons

**`POST /api/coupons/validate`**

```json
{
  "code": "EID20",
  "amount": 5000,
  "tailor_id": "T001"
}
```

Response `200`:

```json
{
  "code": "EID20",
  "valid": true,
  "discount_percent": 20,
  "discount_amount": 1000,
  "message": "20% discount applied!"
}
```

An unknown or expired code also returns `200`, with `valid` false, both discounts 0 and a message to show.

When the order is placed, send the code as `coupon_code` in `POST /api/orders`. `placeOrder` has an optional `couponCode` parameter for it. The server works out the discount again and never trusts the amount the app sends. Nothing in the admin panel creates coupons, so they start as seed data.

### 3.6 Saved measurements

One set per customer.

**`GET /api/measurements`**

```json
{
  "unit": "cm",
  "height": 165,
  "weight": 60,
  "chest": 36,
  "waist": 30,
  "hips": 38,
  "shoulder": 15,
  "arm_length": 24,
  "inseam": 28,
  "neck": 14,
  "wrist": 6,
  "updated_at": "2026-10-01T09:30:00.000Z"
}
```

`404` when the customer has saved nothing yet. `weight` is always in kilograms. The other nine values are in `unit`.

**`PUT /api/measurements`**

Send the same fields without `updated_at`. Creates the set the first time and replaces it afterwards. Returns the saved set.

These measurements are separate from an order. The place order screen still sends its own five values, in inches, as one string.

### 3.7 Saved payment methods

**`GET /api/payment-methods`**

```json
[
  {
    "id": "PM001",
    "type": "jazzCash",
    "detail": "0301-2345678",
    "account_name": "Ayesha Khan",
    "is_default": true
  }
]
```

These are the accounts a customer adds money to the wallet from (3.7a). `detail` is the text the list shows: the mobile number of a wallet, the bank and the last four digits of a bank account, or the last four digits of a card. A bank account also carries `bank_name`.

**`POST /api/payment-methods`**

```json
{
  "type": "bank",
  "bank_name": "Meezan Bank",
  "account_number": "0123456789012",
  "account_name": "Ayesha Khan"
}
```

Send `iban` instead of `account_number` to use an IBAN, which is checked for typing mistakes. `bank_name` must be one of the names from `GET /api/banks`, and an account number has 8 to 20 digits. A wallet takes the mobile number as `account_number` (`type` `jazzCash` or `easyPaisa`), and a card takes its number. Returns `201` with the new item. The first account a customer saves becomes the default. Full bank and card numbers are never kept, only the last four digits.

**`GET /api/banks`**

The bank names to choose from, as an array of strings. Customers and tailors both use it.

**`PUT /api/payment-methods/:id/default`**

No body. Returns the updated item. The previous default loses the flag.

**`DELETE /api/payment-methods/:id`**

Returns `204`. `409` when it is the default method.

### 3.7a Wallet

Orders and gifts are paid from the customer's wallet, which the customer fills from a saved account. The balance and every change are kept on the server.

**`GET /api/wallet`**

```json
{
  "balance": 3000,
  "transactions": [
    {
      "id": "665f...",
      "type": "topup",
      "amount": 3000,
      "balance_after": 3000,
      "description": "Added Rs 3,000 from Meezan Bank ••••6702",
      "order_id": null,
      "created_at": "2026-11-01T09:30:00.000Z"
    }
  ]
}
```

`type` is `topup`, `payment`, `refund` or `gift`. `amount` is positive when money comes in and negative when it goes out. The list has the latest 50, newest first.

**`POST /api/wallet/top-up`**

```json
{
  "method_id": "PM001",
  "amount": 3000
}
```

The customer chooses the amount, a whole number from 100 to 200,000, and the account it comes from. Returns `201` with the wallet in the shape above. `404` when the account is not the customer's. Until a payment provider is connected, the money is not taken from a real account (decision 19).

**`POST /api/payments`**

```json
{
  "order_id": "ORD-1001"
}
```

Pays the order from the wallet. The amount is the order's own price, never one the app sends. Returns `201` with the payment, whose `method` is `wallet`. `409` when the order is already paid, and `409` when the wallet has too little, with a message such as "Your wallet has Rs 500 and this needs Rs 4,000. Add Rs 3,500 to your wallet first." A rejected or cancelled paid order is refunded to the wallet.

### 3.8 Wishlist

The wishlist holds designs from the recommendation catalogue in 3.9. The Saved number on the customer profile is the length of this list.

**`GET /api/wishlist`**

An array of design objects, as in 3.9.

**`POST /api/wishlist`**

```json
{
  "design_id": "D001"
}
```

Returns `204`. Saving a design twice is not an error.

**`DELETE /api/wishlist/:designId`**

Returns `204`.

### 3.9 Searches and AI recommendations

**`POST /api/searches`**

The app sends every search of three characters or more, from the recommendations search bar and from the browse tailors search bar.

```json
{
  "query": "bridal lehenga"
}
```

Returns `201`. The server works out the category.

```json
{
  "query": "bridal lehenga",
  "category": "Bridal",
  "created_at": "2026-10-07T04:50:00.000Z"
}
```

**`GET /api/searches`**

The signed-in customer's own searches, newest first, as an array of the object above.

**`GET /api/searches/trending?limit=10`**

The most frequent searches of all customers in the last seven days, highest count first. `limit` defaults to 10.

```json
[
  { "query": "Bridal Lehenga", "count": 14 }
]
```

**`GET /api/ai/recommendations?query=&limit=`**

With `query`, the designs most similar to it. Without `query`, designs picked from the customer's own recent searches. `limit` defaults to 6.

```json
[
  {
    "id": "D001",
    "name": "Heavy Bridal Lehenga",
    "category": "Bridal",
    "price_min": 4500,
    "price_max": 8000,
    "image_url": null
  }
]
```

`category` is Bridal, Formal, Eastern, Casual, Western or General. The screen picks a colour from it.

### 3.10 AI design studio

**`POST /api/ai/designs`**

```json
{
  "prompt": "A red bridal lehenga with golden embroidery and floral patterns",
  "category": "Bridal",
  "color": "Red",
  "fabric": "Silk"
}
```

Returns `201` with four design concepts.

```json
[
  {
    "id": "AID1001",
    "title": "Classic Elegance",
    "category": "Bridal",
    "color": "Red",
    "fabric": "Silk",
    "image_url": "https://example.com/uploads/designs/aid1001.png"
  }
]
```

**`POST /api/ai/designs/:id/send`**

```json
{
  "tailor_id": "T001"
}
```

Returns `204`. The tailor gets a notification with the design. The studio opens from the AI Design tile on the customer home screen, and Send to Tailor opens a tailor picker. The screen does not call `generateDesigns` or this endpoint yet, so after a tailor is picked it only shows a message.

### 3.11 Virtual try-on

The app talks only to the Node API, which passes the request to the Flask service. The service asks a hosted try-on model (IDM-VTON on Replicate) to dress the customer's photo in the garment photo (decision 11).

**`POST /api/ai/try-on`**

Multipart form data with two image files, `photo` (the customer, full body) and `garment` (the dress), plus `garment_type` and an optional `command` that describes the garment, such as "Long red silk lehenga with gold embroidery". The call takes 20 to 60 seconds, and the app shows a processing state while it waits. Returns `201`.

```json
{
  "id": "TRY1001",
  "garment_type": "Bridal Lehenga",
  "command": "Long red silk lehenga with gold embroidery",
  "result_url": "https://example.com/uploads/try-on/try1001-result.png",
  "is_saved": false,
  "created_at": "2026-10-07T04:55:00.000Z"
}
```

`400` when a photo is missing or cannot be read. `502` when the model cannot make an image from the photos, and the message says what to try. `503` when the try-on service or its Replicate token is not set up. `504` when the model takes more than about two and a half minutes.

**`PUT /api/ai/try-on/:id/save`**

No body. Returns the result with `is_saved` true. Share uses the phone's share sheet and needs no endpoint.

### 3.12 Payout accounts and withdrawals

For tailors.

**`GET /api/payout-accounts`**

```json
[
  {
    "id": "PA001",
    "type": "bank",
    "account_number": "0123-4567890",
    "account_name": "Shahid Tailor",
    "bank_name": "HBL",
    "iban": null,
    "is_default": true
  }
]
```

**`POST /api/payout-accounts`**

```json
{
  "type": "bank",
  "account_number": "0123-4567890",
  "account_name": "Shahid Tailor",
  "bank_name": "HBL",
  "iban": "PK36HABB0000123456789012"
}
```

Returns `201` with the new account. A `bank` account needs `bank_name` from `GET /api/banks` and an account number of 8 to 20 digits, and `iban` is optional and checked when it is sent. For `jazzCash` and `easyPaisa`, `account_number` is the mobile number. The first account becomes the default.

**`PUT /api/payout-accounts/:id/default`**

No body. Returns the updated account.

**`DELETE /api/payout-accounts/:id`**

Returns `204`. `409` when it is the default account.

**`GET /api/withdrawals`**

The user's withdrawals, newest first. The payout history on the tailor payment screen shows the `paid` ones.

```json
[
  {
    "id": "WD004",
    "amount": 12400,
    "status": "paid",
    "requested_at": "2026-05-25T09:00:00.000Z",
    "paid_at": "2026-05-26T11:30:00.000Z"
  }
]
```

**`POST /api/withdrawals`**

```json
{
  "amount": 4200
}
```

`amount` is optional. The Withdraw button sends none, which means the whole available balance. Returns `201` with the withdrawal as `pending`. `400` when the amount is below Rs 500 or above the available balance. `409` when the user has no payout account.

The app says payouts are processed every Monday, so a `pending` withdrawal becomes `paid` then. Nothing in the admin panel lists or pays withdrawals yet.

### 3.13 Chat

Each order has one conversation, between its customer and its tailor, so the order ID identifies it.

**`GET /api/conversations`**

One entry per order of the signed-in user, most recent activity first.

```json
[
  {
    "order_id": "ORD001",
    "garment_type": "Bridal Lehenga",
    "other_user_id": "T001",
    "other_user_name": "Sana's Couture",
    "last_message": "Perfect, thank you so much!",
    "last_message_at": "2026-10-07T03:05:00.000Z",
    "unread_count": 0
  }
]
```

An order with no messages has an empty `last_message` and a null `last_message_at`.

**`GET /api/orders/:id/messages`**

Oldest first.

```json
[
  {
    "id": "MSG001",
    "sender_id": "C001",
    "receiver_id": "T001",
    "text": "Hello! I wanted to check on my order ORD001.",
    "type": "text",
    "is_read": true,
    "created_at": "2026-10-07T02:20:00.000Z"
  }
]
```

**`POST /api/orders/:id/messages`**

```json
{
  "text": "When will it be ready?",
  "type": "text"
}
```

Returns `201` with the new message. `403` when the user is neither the order's customer nor its tailor.

**`PUT /api/orders/:id/messages/read`**

No body. Marks every message addressed to the signed-in user as read. Returns `204`.

### 3.14 Notifications

`NotificationService.getNotifications` calls the existing `GET /api/notifications` without `userId`. The tailor notifications screen uses it too.

```json
[
  {
    "id": "N001",
    "title": "Order Update",
    "body": "Your bridal lehenga is In Progress!",
    "type": "order",
    "is_read": false,
    "created_at": "2026-10-07T04:40:00.000Z"
  }
]
```

**`PUT /api/notifications/:id/read`**

No body. Returns `204`.

**`PUT /api/notifications/read-all`**

No body. Returns `204`.

### 3.16 Live stream

These endpoints cover the tailor's side. The customer's side is in 3.24. Every stream object also carries `tailor_name`, the business name, so the customer app can list streams without loading each tailor.

**`POST /api/streams`**

```json
{
  "title": "Bridal Lehenga Live Stitching Session",
  "category": "Bridal Work",
  "gifts_enabled": true
}
```

Returns `201` with the stream.

```json
{
  "id": "LIVE1001",
  "tailor_id": "T001",
  "title": "Bridal Lehenga Live Stitching Session",
  "category": "Bridal Work",
  "status": "live",
  "gifts_enabled": true,
  "viewers": 0,
  "peak_viewers": 0,
  "likes": 0,
  "earnings": 0,
  "duration_seconds": 0,
  "pinned_garment_id": null,
  "started_at": "2026-10-07T18:00:00.000Z",
  "gifts": []
}
```

`category` is the text the tailor picks: Bridal Work, Stitching Tutorial, Design Showcase or Q&A Session.

**`GET /api/streams/:id`**

The same object with the current numbers. The app asks again every few seconds while the stream is live.

**`GET /api/streams/:id/messages`**

The latest 40 chat lines, oldest first.

```json
[
  {
    "id": "LM001",
    "viewer_name": "Fatima K.",
    "text": "Can you make this for me?",
    "created_at": "2026-10-07T18:02:10.000Z"
  }
]
```

**`POST /api/streams/:id/video-token`**

No body. For the tailor who owns the live stream it returns a token that lets them publish video into the stream's LiveKit room; for any other signed-in user it returns a watch-only token. The room is the stream's `id`. Tokens last 4 hours.

```json
{
  "url": "wss://sewsmart-xxxx.livekit.cloud",
  "token": "eyJhbGciOi..."
}
```

`403` for a tailor who does not own the stream, `409` once it has ended, `503` ("Live video is not set up on this server yet.") when `LIVEKIT_URL`, `LIVEKIT_API_KEY` and `LIVEKIT_API_SECRET` are not set. The secret stays on the server.

**`PUT /api/streams/:id/pin`**

```json
{
  "garment_id": "G002"
}
```

Pins an item from the tailor's price list so viewers can order it. Returns the updated stream.

**`PUT /api/streams/:id/end`**

No body. Returns the stream with `status` `ended`, the final numbers, and one `gifts` entry per gift type received.

```json
{
  "id": "LIVE1001",
  "tailor_id": "T001",
  "title": "Bridal Lehenga Live Stitching Session",
  "category": "Bridal Work",
  "status": "ended",
  "gifts_enabled": true,
  "viewers": 0,
  "peak_viewers": 212,
  "likes": 1840,
  "earnings": 700,
  "duration_seconds": 1260,
  "pinned_garment_id": "G002",
  "started_at": "2026-10-07T18:00:00.000Z",
  "gifts": [
    { "name": "Rose", "amount": 50, "count": 4 },
    { "name": "Crown", "amount": 500, "count": 1 }
  ]
}
```

`earnings` is the total of the gifts and is added to the tailor's available balance. The gift types are fixed in the app: Star Rs 10, Rose Rs 50, Diamond Rs 100 and Crown Rs 500.

### 3.17 Garment categories

**`GET /api/categories`**

The list the admin manages in settings (4.11), for the category chips on the browse tailors screen. The screen adds its own All chip in front.

```json
["Bridal", "Eastern", "Western", "Casual", "Children"]
```

### 3.18 Endpoints added on 11 October 2026

These serve the screens built on 11 October 2026. The new screens call these through the services. Two services are new in `lib/core/services/`: `SupportService` for disputes and content reports, and `VerificationService` for tailor documents.

| Endpoint | Service method | Screen that needs it |
| --- | --- | --- |
| `GET /api/addresses` | `CustomerService.getAddresses` | Addresses |
| `POST /api/addresses` | `CustomerService.addAddress` | Addresses |
| `PUT /api/addresses/:id` | `CustomerService.updateAddress` | Addresses |
| `PUT /api/addresses/:id/default` | `CustomerService.setDefaultAddress` | Addresses |
| `DELETE /api/addresses/:id` | `CustomerService.removeAddress` | Addresses |
| `GET /api/verifications/me` | `VerificationService.getMyVerification` | Verification, tailor dashboard |
| `POST /api/verifications` | `VerificationService.submitVerification` | Verification |
| `POST /api/disputes` | `SupportService.raiseDispute` | Report a problem, for customers and tailors |
| `GET /api/disputes` | `SupportService.getMyDisputes` | Order tracking, tailor order detail |
| `POST /api/content-reports` | `SupportService.reportContent` | Tailor profile, live stream viewer |
| `GET /api/streams?status=live` | `CustomerService.getLiveStreams` | Customer home, Live Now |
| `POST /api/streams/:id/join` | `CustomerService.joinStream` | Live stream viewer |
| `POST /api/streams/:id/leave` | `CustomerService.leaveStream` | Live stream viewer |
| `POST /api/streams/:id/messages` | `CustomerService.sendStreamMessage` | Live stream viewer |
| `POST /api/streams/:id/like` | `CustomerService.likeStream` | Live stream viewer |
| `POST /api/streams/:id/gifts` | `CustomerService.sendGift` | Live stream viewer |


### 3.19 Reviews

**`POST /api/reviews`**

```json
{
  "order_id": "ORD002",
  "tailor_id": "T002",
  "rating": 5,
  "comment": "Lovely fitting.\nPerfect fitting · On-time delivery"
}
```

`rating` is a whole number from 1 to 5. `comment` may be empty, and the tags the customer picked arrive as its last line. The customer comes from the token. The service also passes `customerId` and `customerName` for the mock, and the backend ignores both. Returns `201` with the review. `403` when the order is not the customer's. `409` when the order is not `delivered` or `completed`, or already has a review. Recalculate the tailor's `rating` afterwards.

The review object, as `GET /api/tailors/:id/reviews` returns it, now carries `order_id`:

```json
{
  "id": "REV004",
  "order_id": "ORD002",
  "customer_id": "C001",
  "tailor_id": "T002",
  "customer_name": "Ayesha K.",
  "rating": 5,
  "comment": "Lovely fitting.",
  "created_at": "2026-10-11T09:30:00.000Z"
}
```

`customer_name` is the first name and an initial. The order tracking screen finds the customer's own review of an order in that list by `order_id`, and shows Rate until there is one.

### 3.20 Addresses

**`GET /api/addresses`**

```json
[
  {
    "id": "AD001",
    "label": "home",
    "street": "House 12, Street 5",
    "area": "Gulberg III",
    "city": "Lahore",
    "phone": "0300-1234567",
    "landmark": "Near Liberty Market",
    "is_default": true
  }
]
```

`label` is `home`, `work` or `other`. `landmark` may be `null`.

**`POST /api/addresses`**

The fields above without `id` and `is_default`. Returns `201` with the new address. `400` when `street`, `area` or `city` is empty, or `phone` is not a mobile number. The first address becomes the default.

**`PUT /api/addresses/:id`**

The same body as `POST`. Returns the updated address. `is_default` does not change here.

**`PUT /api/addresses/:id/default`**

No body. Returns the updated address. The previous default loses the flag.

**`DELETE /api/addresses/:id`**

Returns `204`. `409` when it is the default address and the customer has other addresses.

### 3.22 Verification documents

Tailors send these, and the admin decides on the Verifications screen (4.5).

**`GET /api/verifications/me`**

The signed-in user's latest request. `404` when they have not sent one.

```json
{
  "id": "VR001",
  "status": "pending",
  "cnic_number": "35202-1234567-1",
  "documents": [
    { "type": "cnicFront", "url": "https://example.com/uploads/documents/vr001-cnic-front.jpg" },
    { "type": "cnicBack", "url": "https://example.com/uploads/documents/vr001-cnic-back.jpg" },
    { "type": "businessProof", "url": "https://example.com/uploads/documents/vr001-proof.jpg" }
  ],
  "submitted_at": "2026-10-11T09:00:00.000Z",
  "rejection_reason": null,
  "admin_message": null
}
```

`status` is `pending`, `approved` or `rejected`. `rejection_reason` is the reason the admin gave with `PUT /api/admin/verifications/:id/reject`. `admin_message` is the message sent with `POST /api/admin/verifications/:id/request-documents`, while the request stays `pending`. The screen offers Send Documents Again in both cases.

**`POST /api/verifications`**

Multipart form data: `cnic_number`, plus one file for each document type, named `cnicFront`, `cnicBack` and `businessProof`. Returns `201` with the new request as `pending`. A new request replaces an open one. `400` when the CNIC is not 13 digits or a document is missing. The app has no image picker yet, so the mock sends file names only.

### 3.23 Disputes and content reports

**`POST /api/disputes`**

```json
{
  "order_id": "ORD002",
  "reason": "Wrong measurements",
  "details": "The sleeves are two inches shorter than the measurements I gave."
}
```

The order's customer or its tailor sends it. `reason` is one of the choices on the screen. A customer picks from Wrong measurements, Poor stitching quality, Late delivery, Damaged or stained, Not as described, Payment or refund, and Other. A tailor picks from Customer not responding, Delivery refused, Wrong measurements given, Payment problem, Abusive behaviour, and Other. `details` has at least 20 characters. Returns `201`:

```json
{
  "id": "DIS-101",
  "order_id": "ORD002",
  "reason": "Wrong measurements",
  "details": "The sleeves are two inches shorter than the measurements I gave.",
  "status": "open",
  "resolution": null,
  "resolution_notes": null,
  "created_at": "2026-10-11T09:40:00.000Z"
}
```

`403` when the user is neither the order's customer nor its tailor. `409` when the order already has an open dispute.

**`GET /api/disputes`**

Disputes on the signed-in user's orders, whoever raised them, newest first, as an array of the object above. For a customer these are their own orders; for a tailor, the orders placed with them. The customer's order tracking screen and the tailor's order detail screen show the latest one for their order, open or resolved, in place of the "Report a problem" link.

**`POST /api/content-reports`**

```json
{
  "target_type": "review",
  "target_id": "REV002",
  "reason": "Fake or misleading",
  "details": ""
}
```

`target_type` is `review`, `design` or `profile`. `details` may be empty. Returns `201`. Reporting the same item twice is not an error. The person reported is not told who reported them.

### 3.24 Watching a live stream

The customer's side of 3.16. The video comes through LiveKit with the token from `POST /api/streams/:id/video-token` (decision 12). Until the API sends live updates (section 5), the viewer screen moves the numbers and plays other viewers' chat by itself, as the tailor's live screen does.

**`GET /api/streams?status=live`**

The streams that are live now, most viewers first, as an array of the stream object in 3.16.

**`POST /api/streams/:id/join`**

No body. Counts the viewer and returns the stream. A stream that has ended comes back with `status` `ended`, and the screen says so.

**`POST /api/streams/:id/leave`**

No body. Returns `204`. Sent when the viewer closes the screen.

**`POST /api/streams/:id/messages`**

```json
{
  "text": "Can you make this in blue?"
}
```

Returns `201` with the new chat line, in the shape of `GET /api/streams/:id/messages`. `viewer_name` comes from the token. `409` when the stream has ended.

**`POST /api/streams/:id/like`**

No body. Returns `204`. A viewer can like many times.

**`POST /api/streams/:id/gifts`**

```json
{
  "gift": "Rose"
}
```

`gift` is Star, Rose, Diamond or Crown. The backend takes the amount from the viewer's wallet (3.7a) and adds it to the stream's `earnings`. Returns `204`. `409` when gifts are off, the stream has ended, or the customer has no payment method.

The pinned item's Order button opens the place order screen with that garment selected.

## 4. Admin panel endpoints

All 36 endpoints are called from `sewsmart_admin/lib/core/services/admin_service.dart`. Every route except login needs an admin token.

### 4.1 Overview

| Endpoint | Service method | Used by |
| --- | --- | --- |
| `POST /api/admin/auth/login` | `login` | Login |
| `POST /api/admin/auth/logout` | `logout` | Sidebar |
| `PUT /api/admin/auth/password` | `changePassword` | Settings |
| `GET /api/admin/stats` | `getStats` | Dashboard |
| `GET /api/admin/revenue/monthly` | `getMonthlyRevenue` | Dashboard |
| `GET /api/admin/tailors/top` | `getTopTailors` | Dashboard |
| `GET /api/admin/users` | `getUsers` | Customers |
| `PUT /api/admin/users/:id/status` | `suspendUser` | Customers |
| `DELETE /api/admin/users/:id` | `deleteUser` | Customers |
| `GET /api/admin/tailors` | `getTailors` | Tailors |
| `PUT /api/admin/tailors/:id/status` | `suspendTailor` | Tailors |
| `DELETE /api/admin/tailors/:id` | `removeTailor` | Tailors |
| `GET /api/admin/verifications` | `getPendingVerifications`, `getAllVerifications` | Verifications, Tailors, Dashboard |
| `PUT /api/admin/verifications/:id/approve` | `approveVerification` | Verifications, Tailors, Dashboard |
| `PUT /api/admin/verifications/:id/reject` | `rejectVerification` | Verifications, Tailors, Dashboard |
| `POST /api/admin/verifications/:id/request-documents` | `requestMoreDocuments` | Verifications, Tailors |
| `GET /api/admin/orders` | `getAllOrders`, `getRecentOrders` | Orders, Dashboard |
| `PUT /api/admin/orders/:id/cancel` | `cancelOrder` | Orders |
| `GET /api/admin/payments` | `getAllPayments` | Payments |
| `GET /api/admin/payments/summary` | `getPaymentSummary` | Payments |
| `GET /api/admin/disputes` | `getDisputes` | Disputes |
| `PUT /api/admin/disputes/:id/resolve` | `resolveDispute` | Disputes |
| `GET /api/admin/reports` | `getReports` | Reports |
| `GET /api/admin/content/designs` | `getDesigns` | Content |
| `DELETE /api/admin/content/designs/:id` | `removeDesign` | Content |
| `GET /api/admin/content/reviews` | `getReviews` | Content |
| `DELETE /api/admin/content/reviews/:id` | `removeReview` | Content |
| `GET /api/admin/content/reports` | `getFlaggedContent` | Content |
| `PUT /api/admin/content/reports/:id/resolve` | `resolveFlaggedContent` | Content |
| `GET /api/admin/settings` | `getSettings` | Settings |
| `PUT /api/admin/settings` | `updateSettings` | Settings |
| `POST /api/admin/settings/categories` | `addCategory` | Settings |
| `DELETE /api/admin/settings/categories/:name` | `removeCategory` | Settings |

### 4.2 Auth

There is no admin sign-up. Create the first admin with a seed script and store the password hashed. `admin` is not a role in the mobile app, so an admin must not be able to sign in through `/api/auth/login`.

**`POST /api/admin/auth/login`**

Request:

```json
{
  "email": "admin@example.com",
  "password": "your-password"
}
```

Response `200`:

```json
{
  "token": "eyJhbGciOiJIUzI1NiJ9.example",
  "admin": {
    "id": "ad001",
    "name": "Admin",
    "email": "admin@example.com"
  }
}
```

`401` when the email or password is wrong.

**`POST /api/admin/auth/logout`**

No body. Returns `204`.

**`PUT /api/admin/auth/password`**

Request:

```json
{
  "current_password": "old-password",
  "new_password": "new-password"
}
```

Returns `204`. `400` when the current password is wrong or the new one is shorter than 8 characters. The app must compare the Confirm Password box itself. It is not sent.

### 4.3 Dashboard

**`GET /api/admin/stats`**

Response `200`:

```json
{
  "total_users": 1248,
  "total_orders": 3874,
  "total_revenue": 2845600,
  "active_orders": 142,
  "pending_verifications": 7,
  "registered_tailors": 312,
  "open_disputes": 4,
  "this_month_revenue": 184200,
  "last_month_revenue": 162500,
  "average_tailor_rating": 4.6
}
```

| Field | Meaning |
| --- | --- |
| `total_users` | All customer and tailor accounts |
| `total_orders` | All orders ever placed |
| `total_revenue` | Sum of `completed` payments, before commission |
| `active_orders` | Orders that are `accepted`, `inProgress`, `qualityCheck` or `readyForDelivery` |
| `pending_verifications` | Verification requests with status `pending` |
| `registered_tailors` | Tailor accounts |
| `open_disputes` | Disputes with status `open` |
| `this_month_revenue`, `last_month_revenue` | `total_revenue` limited to the current and the previous calendar month |
| `average_tailor_rating` | Average rating across tailors that have at least one review, to one decimal |

**`GET /api/admin/revenue/monthly?months=6`**

`months` defaults to 6. The array is oldest first, because the chart draws it left to right. `month` is `YYYY-MM` and the app shows the short month name.

```json
[
  { "month": "2024-05", "revenue": 162500 },
  { "month": "2024-06", "revenue": 184200 }
]
```

**`GET /api/admin/tailors/top?limit=5`**

`limit` defaults to 5. Highest revenue first.

```json
[
  {
    "id": "ta001",
    "name": "Noor Stitching Studio",
    "city": "Lahore",
    "total_orders": 156,
    "rating": 4.8,
    "revenue": 284500,
    "completion_rate": 97.4
  }
]
```

`completion_rate` is a percentage: completed orders out of the tailor's finished orders, where finished means completed, cancelled or rejected.

The Recent Orders card uses `GET /api/admin/orders?limit=5`, described in 4.6.

### 4.4 Customers and tailors

The three lists follow one pattern. Each has its own endpoint because the rows carry different fields.

**`GET /api/admin/users?role=&status=`**

`role` defaults to `customer`, which is the only value the Customers screen uses. `status` is `active` or `suspended`.

```json
[
  {
    "id": "cu001",
    "name": "Ayesha Malik",
    "email": "ayesha.malik@email.com",
    "phone": "+92-300-1234567",
    "city": "Lahore",
    "role": "customer",
    "status": "active",
    "created_at": "2024-01-15T00:00:00.000Z",
    "total_orders": 12,
    "total_spent": 45600
  }
]
```

`total_orders` and `total_spent` are calculated from the customer's orders and completed payments.

**`GET /api/admin/tailors?status=`**

```json
[
  {
    "id": "ta001",
    "name": "Noor Stitching Studio",
    "email": "noor.studio@email.com",
    "phone": "+92-300-9991234",
    "city": "Lahore",
    "category": "Bridal",
    "status": "active",
    "is_verified": true,
    "created_at": "2023-11-10T00:00:00.000Z",
    "total_orders": 156,
    "rating": 4.8,
    "revenue": 284500
  }
]
```

**`PUT /api/admin/users/:id/status`**, **`PUT /api/admin/tailors/:id/status`**

Request:

```json
{
  "status": "suspended"
}
```

Returns the updated object. The body carries the status you want, not a toggle, so a repeated request cannot undo itself. A suspended account cannot sign in.

**`DELETE /api/admin/users/:id`**, **`DELETE /api/admin/tailors/:id`**

Returns `204`. Keep the account's orders, payments and reviews. Mark the account as deleted instead of removing the document, so order history and revenue totals stay correct.

### 4.5 Verifications


**`GET /api/admin/verifications?status=`**

`status` is `pending`, `approved` or `rejected`. The screens filter by role themselves.

```json
[
  {
    "id": "pv001",
    "name": "Modern Stitching Co.",
    "phone": "+92-301-2223334",
    "city": "Karachi",
    "role": "tailor",
    "submitted_at": "2024-06-01T00:00:00.000Z",
    "status": "pending",
    "documents_submitted": true
  }
]
```

`documents_submitted` is `true` when the business proof is on file.

**`PUT /api/admin/verifications/:id/approve`**

No body. Sets the request to `approved`, sets the account's `is_verified` to `true` and notifies the applicant.

**`PUT /api/admin/verifications/:id/reject`**

Request:

```json
{
  "reason": "CNIC photo is not readable"
}
```

Sets the request to `rejected` and notifies the applicant with the reason.

**`POST /api/admin/verifications/:id/request-documents`**

Request, where `message` is optional:

```json
{
  "message": "Please upload a clearer photo of your CNIC"
}
```

Returns `204`. The request stays `pending` and the applicant gets a notification.

### 4.6 Orders

**`GET /api/admin/orders?status=&limit=`**

`status` is one order status. The Orders screen loads every order once and filters its tabs and search box locally, so it sends no filter. The dashboard sends `limit=5`.

```json
[
  {
    "id": "ORD-002",
    "customer_id": "cu002",
    "customer_name": "Sara Ahmed",
    "tailor_id": "ta002",
    "tailor_name": "Karachi Fashion House",
    "garment_type": "Evening Gown",
    "amount": 8400,
    "status": "inProgress",
    "created_at": "2024-06-01T00:00:00.000Z",
    "city": "Karachi"
  }
]
```

This is the mobile order object plus `city`, the customer's city. Extra mobile fields such as `measurements` and `notes` may be returned. The admin panel ignores them.

**`PUT /api/admin/orders/:id/cancel`**

No body. Sets the order to `cancelled`. `409` when the order is already `delivered`, `completed`, `rejected` or `cancelled`.

### 4.7 Payments

**`GET /api/admin/payments?method=&status=`**

```json
[
  {
    "id": "PAY-0421",
    "transaction_id": "TXN-8821",
    "order_id": "ORD-001",
    "customer_name": "Ayesha Malik",
    "tailor_name": "Noor Stitching Studio",
    "amount": 12500,
    "method": "jazzCash",
    "status": "completed",
    "created_at": "2024-05-28T00:00:00.000Z"
  }
]
```

This is the mobile payment object plus the two names. The admin table shows `transaction_id`.

**`GET /api/admin/payments/summary`**

```json
{
  "total_revenue": 18900,
  "this_month": 5670,
  "pending": 26400,
  "refunded": 7800
}
```

| Field | Meaning |
| --- | --- |
| `total_revenue` | Sum of `completed` payments |
| `this_month` | Sum of `completed` payments in the current calendar month |
| `pending` | Sum of `pending` payments |
| `refunded` | Sum of `refunded` payments |

### 4.8 Disputes

**`GET /api/admin/disputes?status=`**

`status` is `open` or `resolved`.

```json
[
  {
    "id": "DIS-002",
    "order_id": "ORD-004",
    "customer_name": "Nadia Hussain",
    "tailor_name": "Islamabad Couture",
    "issue": "Garment measurements not matching specifications",
    "amount": 4600,
    "created_at": "2024-05-22T00:00:00.000Z",
    "status": "resolved",
    "resolution": "refund",
    "resolution_notes": "Partial refund of Rs. 1200 issued"
  }
]
```

`resolution` and `resolution_notes` are `null` while the dispute is open. Disputes come from `POST /api/disputes` (3.23). `issue` joins the `reason` and `details` the user sent, and `amount` is the order amount.

**`PUT /api/admin/disputes/:id/resolve`**

Request:

```json
{
  "resolution": "refund",
  "notes": "Full refund issued and tailor warned"
}
```

Sets the dispute to `resolved` and stores both values. `409` when it is already resolved.

### 4.9 Reports

**`GET /api/admin/reports?range=thisMonth`**

`range` is `today`, `thisWeek`, `thisMonth` or `custom`. A `custom` range also needs `from` and `to` as `YYYY-MM-DD`.

| Field | Content |
| --- | --- |
| `range` | The range that was applied |
| `stats` | The object from `GET /api/admin/stats` |
| `monthly_revenue` | The array from `GET /api/admin/revenue/monthly`, always the last six months |
| `revenue_by_category` | Array of `{ "category": "Bridal", "amount": 742000 }`. The app picks the chart colours. |
| `top_tailors` | The array from `GET /api/admin/tailors/top` |
| `order_status_distribution` | Order count per status, for example `{ "pending": 287, "inProgress": 142, "completed": 2841, "cancelled": 604 }` |

The range applies to `total_orders` and `total_revenue` inside `stats`, and to `revenue_by_category`, `top_tailors` and `order_status_distribution`. Every other number is a current total.

### 4.10 Content moderation

Designs are the portfolio samples that tailors upload.

**`GET /api/admin/content/designs`**

```json
[
  {
    "id": "d005",
    "creator_name": "Raza Tailoring Works",
    "title": "Men's Casual Wear",
    "type": "design",
    "status": "flagged",
    "created_at": "2024-05-25T00:00:00.000Z"
  }
]
```

**`DELETE /api/admin/content/designs/:id`**

Returns `204`.

**`GET /api/admin/content/reviews`**

```json
[
  {
    "id": "r002",
    "customer_name": "Sara Ahmed",
    "tailor_name": "Karachi Fashion House",
    "rating": 2,
    "comment": "Very disappointed with the quality and late delivery.",
    "created_at": "2024-06-02T00:00:00.000Z",
    "status": "published"
  }
]
```

`rating` is a number from 1 to 5.

**`DELETE /api/admin/content/reviews/:id`**

Returns `204`. Recalculate the tailor's average rating afterwards.

**`GET /api/admin/content/reports?status=`**

`status` is `pending` or `resolved`.

```json
[
  {
    "id": "f001",
    "reporter_name": "Amna Butt",
    "reported_item": "Design by Raza Works",
    "target_type": "design",
    "target_id": "d005",
    "reason": "Inappropriate image content",
    "created_at": "2024-06-01T00:00:00.000Z",
    "status": "pending"
  }
]
```

`reported_item` is the text the admin reads. `target_type` is `design`, `review` or `profile`, and with `target_id` it tells the backend what the report points at. Reports come from `POST /api/content-reports` (3.23), and the backend fills in `reporter_name` and `reported_item`.

**`PUT /api/admin/content/reports/:id/resolve`**

Request:

```json
{
  "action": "remove"
}
```

Sets the report to `resolved`. `remove` deletes the reported design or review, `warn` notifies its owner, and `dismiss` closes the report with no other effect.

### 4.11 Settings

**`GET /api/admin/settings`**

```json
{
  "commission_rate": 8.5,
  "categories": ["Bridal", "Eastern", "Western", "Casual", "Children"],
  "notify_new_order": true,
  "notify_order_complete": true,
  "notify_new_verification": true,
  "notify_dispute": true,
  "notify_payment": false,
  "notify_marketing": false,
  "two_fa_enabled": false,
  "session_timeout": 30
}
```

| Field | Meaning |
| --- | --- |
| `commission_rate` | Percentage the platform keeps from each transaction, from 2 to 20 in steps of 0.5 |
| `categories` | Garment categories. Change them with the two category endpoints. |
| `notify_*` | Which events notify the admin |
| `two_fa_enabled` | Stored only. The login screen has no second step yet. |
| `session_timeout` | Minutes of inactivity before the admin is signed out: 15, 30, 60 or 120 |

**`PUT /api/admin/settings`**

Send any of the fields above except `categories`. Fields that are left out keep their value. Returns the full settings object.

**`POST /api/admin/settings/categories`**

Request:

```json
{
  "name": "Formal"
}
```

Returns `201` with the updated list of category names. `400` when the name is empty and `409` when it already exists.

**`DELETE /api/admin/settings/categories/:name`**

URL-encode the name. Returns `204`. Tailors that already use the category keep it.

### 4.12 Left for later

These parts of the admin panel are outside this draft, because the screen or the data behind them is not ready.

- Document files on a verification request. The cards show CNIC front, CNIC back and business proof or driving licence, but nothing is uploaded yet. Add a `documents` array of `{ "type", "url" }` once file upload exists.
- An `image_url` on designs. The cards show a coloured placeholder.
- Status dates for the order timeline. The dialog works them out from the current status and repeats the order date.
- The change badges on the stat cards, such as +12%. They are fixed text.
- The Export buttons. They only show a message.
- A date picker for the Custom report range.
- The search and notification icons in the top bar. Their handlers are empty.

## 5. Not designed yet

Every feature in both apps now has its endpoints named. These parts are still open.

| Open part | Why |
| --- | --- |
| Request and response details of the 29 endpoints in 3.1 | Only their methods and paths are fixed. Each needs the same detail as the newer endpoints before its backend work starts. |
| File uploads | The portfolio and try-on endpoints take multipart form data, the design reference on an order and the verification documents. They are JPEG or PNG images up to 5 MB, saved on the server in `uploads/` and served from `/uploads`. The apps pick them with the camera or gallery. |
| Live video | Tailors and viewers have their endpoints (3.16 and 3.24), and video runs through LiveKit (decision 12). Chat and gifts still update by polling. |
| Delivery address of an order | Customers keep addresses (3.20), but an order and its delivery schedule do not say which one to use. This draft delivers to the default address (decision 15). |
| Saved try-on results | Results can be saved with `PUT /api/ai/try-on/:id/save`, but no endpoint lists them and no screen shows them. The try-on screen has to call `generateTryOn` first. |
| Paying withdrawals | The mobile app can request a withdrawal, but no admin screen lists or pays them. |
| Coupons | The app can validate a code, but no admin screen creates one. |
| Live updates | Chat, notifications and stream numbers are read by asking again. Socket.IO can deliver them live later without changing these endpoints. |
| Push notifications | Nothing registers a device for push yet. |

The screens that were missing were built on 11 October 2026: Reset Password, Rate Your Tailor, Saved Designs, Addresses, Report a Problem (customer and tailor), reporting a review or a tailor profile, Live Now and the live stream viewer, and Verification for tailors. The AI design studio opens from the customer home screen and has a tailor picker. Still without a screen: a list of saved try-on results.

## 6. Decisions to confirm

Each item states what this draft assumes. Change the draft if the team decides otherwise.

1. **One set of values for both apps.** The mobile app reads `inProgress`, `completed` and `jazzCash`. The admin panel shows In Progress, Paid and JazzCash. This draft makes the API use the mobile spelling everywhere, and the admin panel converts values to labels.
2. **Commission rate.** Admin settings start at 8.5%, while the tailor payout screen says "Platform fee: 5% per completed order". This draft treats `commission_rate` as the only source, so the mobile text should read it from the API.
3. **Garment categories.** The mobile app lists Bridal, Eastern, Western, Casual and Formal. Admin settings list Bridal, Eastern, Western, Casual and Children. This draft treats admin settings as the only list, and the mobile app reads it with `GET /api/categories`.
4. **Refunds.** The resolve dialog has no amount field, so a `refund` resolution refunds the full dispute amount. Cancelling an order that is already paid does not refund it automatically.
5. **Revenue.** Every revenue figure is the gross amount customers paid, as the Payments screen calculates it today, not the commission the platform earned.
7. **Reports against a profile.** `remove` is defined for designs and reviews only. What it does to a reported profile is open.
8. **Cash on delivery.** Not offered. Orders are paid from the wallet.
9. **Price lists.** `GET /api/garments/pricing` is one shared list, while each tailor edits their own list. This draft treats the tailor's own list as the real one, so the place order and tailor profile screens should load `GET /api/tailors/:id/garments`.
10. **Recommended designs.** The recommendations come from a catalogue of designs with a name, a category and a price range. Whether that catalogue is seeded by the team or built from the tailors' portfolio samples is open.
11. **Try-on result.** The model returns one image, in one request that waits for the result. A true 3D view, for example a Blender turntable, is not built.
12. **Live video.** Video and sound go through LiveKit. The API keeps the title, the numbers and the chat, and hands out short-lived tokens (`POST /api/streams/:id/video-token`); the LiveKit secret stays in the server's environment. Going live ends the stream again if the video cannot start, so viewers never see an empty one.
13. **Password length.** The register screen accepts 4 characters, and this draft asks for 8 on the admin password. One rule for both would be simpler.
14. **One review per order.** A customer reviews each delivered or completed order once, and cannot edit it afterwards.
15. **Delivery address.** The tailor delivers to the customer's default address. The delivery schedule call does not choose an address yet.
17. **Gifts.** A gift is taken from the viewer's wallet when it is sent and is not refunded.
18. **Reset code.** The reset email shows the token as a code as well as a link, because the app does not open links yet.
19. **Wallet money.** Adding money to the wallet is a sandbox: no real bank, wallet or card is charged, because the project has no merchant account. The wallet balance, payments and refunds are real records. Connecting JazzCash, EasyPaisa or a bank means replacing `charge` in `backend/src/services/paymentGateway.js`.
