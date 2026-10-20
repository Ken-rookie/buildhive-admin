# BUILDHIVE Admin Panel (HTML, CSS, JavaScript)

A separate desktop-first admin website based on the provided BUILDHIVE UI flow. Files are split by responsibility for easier debugging.

## Folder structure

- `index.html` — login screen, app shell, reusable dialogs
- `css/styles.css` — theme, layout, responsive behavior and UI components
- `js/config.js` — Supabase URL, publishable/anon key, currency and low-stock threshold
- `js/app.js` — authentication, profile-role check, data loading, rendering and actions
- `sql/admin_setup.sql` — profile-role protection and starter RLS policies

## 1. Configure Supabase

The ZIP's Flutter app points to `https://seblbbfahvdepfiguepp.supabase.co`. `js/config.js` is prefilled with that project URL. Paste the **publishable key or legacy anon key** from Supabase Project Settings → API into `SUPABASE_ANON_KEY`.

Never use a `service_role` or secret key in browser code. The publishable/anon key is intended to be public; security must be enforced by Supabase Auth and RLS.

## 2. Set up an administrator

1. In Supabase Authentication, create the administrator user with email and password.
2. Open the Supabase SQL Editor and run `sql/admin_setup.sql`.
3. Set that user's existing profile role to `admin`, replacing the email:

```sql
update public.profiles
set role = 'admin'
where id = (
	select id from auth.users
	where lower(email) = lower('admin@example.com')
);
```

4. Verify the profile role is `admin`, then sign in on the website.

The UI checks `profiles.role` on sign-in. Do not rely on hiding menu items for security.

## 3. Run locally

Because the Supabase JavaScript SDK is loaded from a CDN, use an internet connection. Open this folder in VS Code and run `index.html` with the Live Server extension, or serve the folder with any static HTTP server. Do not open with `file://` if your browser blocks authentication redirects or local requests.

## Backend assumptions taken from the supplied Flutter project

- `products`: `id`, `name`, `description`, `price`, `stock_quantity`, `category_id`, `is_active`, `unit`, `image_url`
- `categories`: `id`, `name`
- `orders`: `id`, `customer_id`, `status`, `payment_method`, `payment_status`, `subtotal`, `delivery_fee`, `total`, `delivery_name`, `delivery_phone`, `delivery_address`, `delivery_landmark`, `delivery_notes`, `created_at`
- `order_items`: `order_id`, `product_id`, `product_name`, `unit_price`, `quantity`
- `profiles`: `id`, `full_name`, `phone` (email may not be stored)
- `payments`: optional; the UI falls back to order payment status if the table is unavailable

The provided SQL in the Flutter ZIP adds delivery municipality/barangay columns and checkout functions, and configures product image storage. It does not define the complete base schema for every table. This admin panel uses the field names found in the app and gracefully reports missing table access, but adapt it if your live schema differs.

## Current functionality

- Supabase email/password sign-in and `profiles.role = 'admin'` validation
- Live reads for catalog, orders, profiles, order items and optional payments
- Dashboard metrics, recent orders, six-month order-total chart and low-stock alerts
- Product create/edit/activate/deactivate (including category, price, stock and image URL)
- Inventory filtering, order searching and order status updates
- Order detail modal with items and delivery/payment fields
- Payment overview, delivery queue, customer directory and order history
- Reports calculated from loaded records and CSV order export
- Responsive sidebar and compact mobile layout

## Important production notes

- Review every existing RLS policy before applying the SQL. The admin policy does not remove customer policies. Make sure customer data remains appropriately scoped.
- `admin_setup.sql` creates the admin policy on existing tables but does not create missing business tables or invent their columns.
- Product images upload to the `product-images` Supabase Storage bucket. Run `sql/admin_setup.sql` to allow administrators to upload; make the bucket public if customer-facing pages need to load its public image URLs.
- Payment state should be changed only by trusted server-side payment verification (for example, a validated provider webhook), not by an arbitrary browser update.
- Delivery driver assignment/live GPS is not in the provided backend. The delivery page shows actual order address and status data only.
- The UI loads up to 500 orders and 1,000 profiles per refresh. For larger production datasets, implement server-side pagination and aggregate reports.
