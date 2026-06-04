// Seeds 10 sample knowledge articles across all 6 categories.
// Run once after Phase 5 deploy.

List<Knowledge_Article__c> articles = new List<Knowledge_Article__c>();

articles.add(new Knowledge_Article__c(
    Name = 'How to reset your password',
    Body__c = 'Click the "Forgot password" link on the login page. Enter your email address. You will receive a password reset email within 5 minutes. Check your spam folder if it does not arrive. The reset link is valid for 1 hour. If you do not receive the email after 10 minutes, ensure that emails from no-reply@example.com are not blocked by your email provider.',
    Category__c = 'Account Access',
    Is_Published__c = true,
    Helpful_Count__c = 42
));

articles.add(new Knowledge_Article__c(
    Name = 'Setting up Single Sign-On (SSO)',
    Body__c = 'To enable SSO, contact your IT admin to configure SAML 2.0 with our service. They will need your IdP metadata URL and the entity ID. After configuration, users can log in via your corporate identity provider. Supported IdPs: Okta, Azure AD, Google Workspace, OneLogin, Ping Identity.',
    Category__c = 'Account Access',
    Is_Published__c = true,
    Helpful_Count__c = 18
));

articles.add(new Knowledge_Article__c(
    Name = 'Two-factor authentication setup',
    Body__c = 'Go to Settings > Security > Two-Factor Authentication. Choose between SMS, authenticator app (recommended), or hardware key. For authenticator apps: scan the QR code with Google Authenticator, Authy, or 1Password, then enter the 6-digit code to confirm. Save your backup codes in a secure location - you will need them if you lose access to your authenticator device.',
    Category__c = 'Account Access',
    Is_Published__c = true,
    Helpful_Count__c = 33
));

articles.add(new Knowledge_Article__c(
    Name = 'Updating your payment method',
    Body__c = 'Navigate to Settings > Billing > Payment Methods. Click "Add new card" and enter your details. To remove an old card, click the trash icon next to it. Changes take effect immediately. Note: your default card is used for all subscription renewals.',
    Category__c = 'Billing',
    Is_Published__c = true,
    Helpful_Count__c = 31
));

articles.add(new Knowledge_Article__c(
    Name = 'Why was I charged twice?',
    Body__c = 'Duplicate charges are usually caused by a payment retry after a temporary card decline. The pending charge will automatically be released within 3-7 business days. If both charges have settled (no longer marked pending), please contact billing for an immediate refund. We never intentionally double-charge customers.',
    Category__c = 'Billing',
    Is_Published__c = true,
    Helpful_Count__c = 56
));

articles.add(new Knowledge_Article__c(
    Name = 'Resolving login errors',
    Body__c = 'Common causes of login failure: (1) Caps Lock is on, (2) Browser cookies are blocked, (3) Two-factor code expired (codes are valid 30 seconds). Try clearing your browser cache or using an incognito window. If the issue persists, your account may be locked after 5 failed attempts - wait 15 minutes or contact support to unlock.',
    Category__c = 'Technical Issue',
    Is_Published__c = true,
    Helpful_Count__c = 25
));

articles.add(new Knowledge_Article__c(
    Name = 'Browser compatibility guide',
    Body__c = 'Our platform supports the latest two major versions of Chrome, Firefox, Safari, and Edge. Internet Explorer is not supported. For best performance, enable JavaScript, allow cookies from our domain, and disable browser extensions that may interfere with web applications (e.g., aggressive ad blockers).',
    Category__c = 'Technical Issue',
    Is_Published__c = true,
    Helpful_Count__c = 12
));

articles.add(new Knowledge_Article__c(
    Name = 'How to report a bug',
    Body__c = 'Open a case with the following details: (1) what you expected to happen, (2) what actually happened, (3) steps to reproduce, (4) your browser version and OS, (5) screenshots if applicable, (6) the URL where you saw the issue. Our engineering team triages bugs within 24 hours and prioritizes by severity.',
    Category__c = 'Bug Report',
    Is_Published__c = true,
    Helpful_Count__c = 8
));

articles.add(new Knowledge_Article__c(
    Name = 'Requesting a new feature',
    Body__c = 'We love hearing your ideas! Submit feature requests via the in-app feedback widget or our public roadmap board at roadmap.example.com. Each quarter we prioritize the most-requested features. You will be notified when your request is shipped or moves to "Planned" status.',
    Category__c = 'Feature Request',
    Is_Published__c = true,
    Helpful_Count__c = 5
));

articles.add(new Knowledge_Article__c(
    Name = 'Contacting our support team',
    Body__c = 'Live chat is available Mon-Fri 9am-6pm EST. Email support@example.com for non-urgent issues - responses within 4 business hours. For urgent production-down issues outside business hours, call our 24/7 emergency line at 1-800-EXAMPLE. Enterprise customers also have a dedicated account manager.',
    Category__c = 'General Inquiry',
    Is_Published__c = true,
    Helpful_Count__c = 22
));

insert articles;
System.debug('Inserted ' + articles.size() + ' knowledge articles.');
for (Knowledge_Article__c a : articles) {
    System.debug(a.Category__c + ': ' + a.Name);
}
