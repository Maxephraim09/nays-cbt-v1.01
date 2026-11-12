import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../theme/app_theme.dart';

const _termsOfService = r'''# TERMS OF SERVICE

## NAYS CBT APPLICATION
**National Association of Yungur Students (NAYS)**

**Effective Date:** 1 November 2026

Welcome to the NAYS CBT Application (National Association of Yungur Students Computer-Based Testing Application).

These Terms of Service govern your access to and use of the NAYS CBT mobile application, its examination services, digital features and associated platforms.

By registering, logging in or using this application, you acknowledge that you have read, understood and agreed to these Terms of Service.

## 1. ABOUT THE APPLICATION
The NAYS CBT Application is an educational and examination platform developed to support digital learning, computer-based testing, academic assessment and educational advancement among members and students of the National Association of Yungur Students.

The application provides access to examinations, questions, academic information, examination results, notifications and other educational services authorized by NAYS.

## 2. USER REGISTRATION AND ACCOUNTS
Users are responsible for maintaining the accuracy of their registration information and keeping their login credentials confidential.

By using the application, you agree to:

- Provide accurate and truthful registration information.
- Use only your assigned or authorized account.
- Keep your password and login credentials secure.
- Avoid sharing your account with other individuals.
- Notify the appropriate administrators if you suspect unauthorized access.
- Ensure that your account information remains up to date.

NAYS reserves the right to restrict, suspend or deactivate accounts involved in unauthorized activities or violations of these Terms.

## 3. EXAMINATION RULES AND REGULATIONS
All users participating in CBT examinations must comply with the examination instructions provided within the application.

Users agree to:

1. Complete examinations independently unless collaboration is expressly permitted.
2. Avoid cheating, impersonation or examination malpractice.
3. Avoid accessing unauthorized materials during examinations.
4. Avoid sharing examination questions or answers without authorization.
5. Submit examination answers within the allocated time.
6. Follow all instructions issued by examination administrators.
7. Avoid exploiting technical errors or security vulnerabilities to gain an unfair advantage.

Any attempt to manipulate examination scores, interfere with examination systems or gain unauthorized access to questions or answers may result in disciplinary action.

## 4. EXAMINATION DURATION AND SUBMISSION
Each examination may have a specified duration, number of questions, pass mark and submission deadline.

Users are responsible for:

- Starting examinations only when ready.
- Monitoring the examination countdown timer.
- Saving and submitting their answers as instructed.
- Ensuring a stable internet connection where required.

Examinations may be automatically submitted when the allocated time expires, depending on the examination configuration.

Network interruptions, device failures or other technical difficulties should be reported promptly to the appropriate support team.

## 5. EXAMINATION RESULTS AND SCORING
Examination results are generated based on submitted answers and the marking criteria configured by authorized examination administrators.

Users acknowledge that:

- Results may be released immediately or at a later date.
- Examination scores may be reviewed where necessary.
- Results may be corrected in cases of verified technical or administrative errors.
- Passing an examination does not automatically guarantee admission, scholarship awards, employment or other benefits unless expressly stated by the relevant authority.

NAYS reserves the right to investigate suspected examination irregularities before confirming results.

## 6. ACCEPTABLE USE
Users must not:

- Hack, disrupt or interfere with the application or its servers.
- Attempt to access another user's account.
- Reverse-engineer or modify the application for unauthorized purposes.
- Upload malicious software or harmful content.
- Use the application for fraudulent or unlawful activities.
- Attempt to manipulate examination records or results.
- Abuse the notification, support or communication systems.

Violations may result in account suspension, examination cancellation or further action under applicable rules and laws.

## 7. INTELLECTUAL PROPERTY RIGHTS
The NAYS CBT Application, its branding, logos, interface, design, software components and associated content are protected by applicable intellectual property laws.

Examination questions, educational materials and other submitted content may belong to NAYS, their respective authors or authorized content providers.

Users may access and use the materials for their intended educational and examination purposes only.

Reproduction, distribution, commercial exploitation or unauthorized publication of protected materials is prohibited without appropriate permission.

## 8. PRIVACY AND DATA PROTECTION
The application may collect and process information necessary to provide its services, including:

- Student registration information.
- Login and authentication details.
- Examination attempts and submitted answers.
- Examination scores and academic records.
- Device and technical information.
- Support requests and communications.

Such information will be processed for account management, examination administration, result management, security and service improvement.

Users are encouraged to review the application's Privacy Policy for further information about data collection, storage, processing, protection and applicable user rights.

NAYS and its authorized service providers should handle personal information in accordance with applicable data protection requirements.

## 9. SERVICE AVAILABILITY
NAYS aims to maintain a reliable and accessible platform. However, uninterrupted service cannot be guaranteed.

The application may occasionally experience:

- Scheduled maintenance.
- Server interruptions.
- Network connectivity problems.
- Software updates.
- Temporary service unavailability.

Where reasonably possible, users will be notified of significant service interruptions or scheduled maintenance.

## 10. THIRD-PARTY SERVICES
Certain application features may depend on third-party services, including internet service providers, hosting providers and other technology platforms.

NAYS is not responsible for interruptions or failures caused by third-party services beyond its reasonable control.

## 11. LIMITATION OF LIABILITY
To the extent permitted by applicable law, NAYS and its authorized service providers shall not be liable for losses arising from circumstances beyond their reasonable control, including network failures, device malfunctions, unauthorized access resulting from compromised user credentials or third-party service interruptions.

Nothing in these Terms excludes liability that cannot legally be excluded under applicable law.

## 12. ACCOUNT SUSPENSION AND TERMINATION
NAYS may suspend or terminate access to the application where a user:

- Violates examination regulations.
- Engages in fraudulent activities.
- Attempts unauthorized access.
- Abuses application services.
- Violates these Terms of Service.

Users may contact the administration for clarification or review of account-related decisions.

## 13. CHANGES TO THESE TERMS
NAYS reserves the right to update or modify these Terms of Service when necessary to reflect changes in application features, examination procedures, organizational policies or applicable legal requirements.

Updated Terms will be made available through the application or other official communication channels.

Continued use of the application after changes take effect constitutes acceptance of the updated Terms, subject to applicable law.

## 14. GOVERNING LAW
These Terms of Service shall be governed by and interpreted in accordance with the laws of the Federal Republic of Nigeria.

Any dispute arising from the use of the application shall be addressed through appropriate resolution procedures in accordance with applicable Nigerian law.

## 15. CONTACT AND SUPPORT
For questions, complaints, technical assistance or clarification concerning these Terms of Service, please contact:

**National Association of Yungur Students (NAYS)**

**Application Developer:**

MGTechs Smart Innovations Limited

**Lead Developer:** Maxwell Ephraim H.

- Email: [mgtechs09@gmail.com](mailto:mgtechs09@gmail.com)
- Phone: 08161595906
- Website: [https://www.mgtechs.com.ng](https://www.mgtechs.com.ng/)

## 16. ACCEPTANCE OF TERMS
By accessing or using the NAYS CBT Application, you acknowledge that you have read, understood and agreed to comply with these Terms of Service.

If you do not agree with these Terms, you should discontinue using the application.

---

**NATIONAL ASSOCIATION OF YUNGUR STUDENTS (NAYS)**

**BƏNA NDO FINI**

*Empowering Yungur Students Through Technology and Education.*

**Developed by MGTechs Smart Innovations Limited**

**© 2026 All Rights Reserved.**
''';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Terms of service')),
    body: SelectionArea(
      child: Markdown(
        data: _termsOfService,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
          h1: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(color: AppTheme.brand(context)),
          h2: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(color: AppTheme.brand(context)),
          p: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6),
          listBullet: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    ),
  );
}
