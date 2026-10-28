# Privacy Policy for SmartMove

**Effective Date:** October 27, 2026  
**Last Updated:** October 27, 2026

SmartMove ("we", "our", or "the app") provides social media planning, AI-assisted content creation, and publishing automation tools. We are committed to protecting your privacy and ensuring transparency regarding how your data is handled.

This Privacy Policy explains what information we collect, how it is used, and how you can exercise control or request the deletion of your data when connecting your Meta (Facebook and Instagram) accounts to SmartMove.

---

## 1. Information We Collect

### A. Authentication & Profile Information
When you register or sign in to SmartMove using email or Facebook Login, we collect:
- **Basic Profile Information:** Your name, email address, and profile identifier (`public_profile`, `email`).
- **Account Credentials:** Encrypted authentication tokens handled securely by our backend authentication service (Supabase).

### B. Meta Platform Data (Facebook Pages & Instagram Accounts)
When you choose to connect your Facebook Pages or Instagram Professional accounts to SmartMove, we request the following permissions:
- `public_profile` & `email`: To verify your identity and authenticate your connection.
- `pages_show_list`: To display the list of Facebook Pages you administer so you can choose which ones to connect.
- `pages_read_engagement`: To retrieve post engagement metrics, insights, and incoming comments.
- `pages_manage_posts`: To publish, update, and schedule posts that you create and approve.
- `instagram_basic` & `instagram_content_publish`: To publish content and view basic insights on connected Instagram Professional accounts.

---

## 2. How We Use Your Information

We use the information collected exclusively to deliver the functionality of SmartMove:
- Authenticating your account and maintaining your active session.
- Publishing, scheduling, and drafting social media posts to the Pages you have linked.
- Displaying post analytics and performance metrics.
- Synchronizing audience comments into your Engagement Inbox and assisting with draft responses.
- Ensuring compliance with automated posting rules and safety guardrails configured by you.

**We do NOT sell, lease, rent, or trade your personal data or Meta access tokens to third parties or advertising networks.**

---

## 3. Data Storage & Security

- **Token Security:** Meta access tokens are encrypted and stored with strict Row Level Security (RLS) policies. Only your authenticated account can access your connected social assets.
- **Server-Side Execution:** Sensitive operations (such as publishing posts and token refreshes) are executed server-side. Access tokens are never exposed to public bundles or unauthorized third parties.
- **Retention:** We only retain your tokens and metadata for as long as your account is active and connected.

---

## 4. User Data Deletion Instructions

In compliance with Meta Platform Terms, you have full control over your data and may request deletion at any time:

### Option A: Revoke Meta Access via Facebook
1. Log into your Facebook account.
2. Go to **Settings & Privacy** > **Settings**.
3. In the left navigation, select **Business Integrations** (or **Apps and Websites**).
4. Find **SmartMove** in the list.
5. Click **Remove** to revoke all app permissions and invalidate all access tokens immediately.

### Option B: Request Complete Deletion of Stored Data
To request complete deletion of your account and all associated tokens, posts, and analytics stored in SmartMove:
1. Disconnect your channels directly within the SmartMove app under **Accounts > Connected Accounts**.
2. Or contact us directly by opening an issue on our GitHub repository:  
   [https://github.com/GentzofGod/socialflow/issues](https://github.com/GentzofGod/socialflow/issues)
3. Upon receiving your request, all associated records, access tokens, and cached metadata will be permanently deleted from our database within 30 days.

---

## 5. Contact Information

If you have any questions, feedback, or concerns regarding this Privacy Policy or your data, please contact the project maintainer via:
- **Repository:** [https://github.com/GentzofGod/socialflow](https://github.com/GentzofGod/socialflow)
