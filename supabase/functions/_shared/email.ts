import { getEmailFromAddress, sendResendEmail } from "./resend.ts";

interface AccountEmailPayload {
  userEmail: string;
  userFullName: string;
  userPassword: string;
  userCNP: string;
  userPhone: string;
  adminEmail: string;
  adminFullName: string;
  modulePermissionsSummary: string;
  verificationLink: string | null;
}

export async function sendAccountCreatedEmails(
  payload: AccountEmailPayload,
): Promise<{ sent: boolean; details: string }> {
  if (!Deno.env.get("RESEND_API_KEY")) {
    const linkNote = payload.verificationLink
      ? " Linkul de confirmare a fost generat, dar nu a putut fi trimis fără RESEND_API_KEY."
      : "";
    return {
      sent: false,
      details:
        `Emailurile nu au fost trimise: RESEND_API_KEY lipsește.${linkNote}`,
    };
  }

  if (!payload.verificationLink) {
    return {
      sent: false,
      details: "Linkul de confirmare nu a putut fi generat. Verificați Redirect URLs în Supabase Auth.",
    };
  }

  const verificationSection = `
Pentru a activa contul, confirmați adresa de email accesând linkul de mai jos:
${payload.verificationLink}

Contul nu poate fi folosit în aplicație până când confirmați emailul.
După confirmare veți primi un email cu datele contului și vă veți putea autentifica în aplicație.
`;

  const userBody = `
Bună ${payload.userFullName},

Contul dvs. ERP Mobile a fost creat de administrator.
${verificationSection}
Cu stimă,
Echipa Dateconta ERP
`.trim();

  const adminBody = `
Bună ${payload.adminFullName},

Ați creat un utilizator nou în ERP Mobile.

Utilizator: ${payload.userFullName}
Email: ${payload.userEmail}
Status: în așteptarea confirmării emailului

Link confirmare (dacă utilizatorul nu primește emailul):
${payload.verificationLink}

Cu stimă,
ERP Mobile
`.trim();

  const userResult = await sendResendEmail({
    to: [payload.userEmail],
    subject: "Confirmați emailul — cont ERP Mobile",
    text: userBody,
  });

  if (!userResult.ok) {
    return {
      sent: false,
      details: `Eroare trimitere către utilizator (${getEmailFromAddress()}): ${userResult.error}`,
    };
  }

  if (payload.adminEmail) {
    const adminResult = await sendResendEmail({
      to: [payload.adminEmail],
      subject: "Utilizator nou creat în ERP Mobile",
      text: adminBody,
    });
    if (!adminResult.ok) {
      return {
        sent: false,
        details: `Email utilizator trimis, dar notificarea admin a eșuat: ${adminResult.error}`,
      };
    }
  }

  return {
    sent: true,
    details: "Email de confirmare trimis utilizatorului. Contul se activează după confirmare.",
  };
}

interface AccountActivatedPayload {
  userEmail: string;
  userFullName: string;
  userPassword: string;
  userCNP: string;
  userPhone: string;
  adminEmail: string;
  modulePermissionsSummary: string;
}

export async function sendAccountActivatedEmail(
  payload: AccountActivatedPayload,
): Promise<{ sent: boolean; details: string }> {
  if (!Deno.env.get("RESEND_API_KEY")) {
    return {
      sent: false,
      details: "Emailul de activare nu a fost trimis: RESEND_API_KEY lipsește.",
    };
  }

  const passwordLine = payload.userPassword
    ? `- Parolă: ${payload.userPassword}`
    : "- Parolă: comunicată de administrator";

  const body = `
Bună ${payload.userFullName},

Contul dvs. ERP Mobile a fost activat cu succes.

Date cont:
- Nume: ${payload.userFullName}
- Email: ${payload.userEmail}
- CNP: ${payload.userCNP}
- Telefon: ${payload.userPhone || "-"}
${passwordLine}

Drepturi module:
${payload.modulePermissionsSummary || "Fără drepturi pe module"}

Vă puteți autentifica în aplicația ERP Mobile.

Cu stimă,
Echipa Dateconta ERP
`.trim();

  const ccDefault = Deno.env.get("ACTIVATION_EMAIL_CC")?.trim() || "ERPMobile@dateconta.ro";
  const ccRecipients = new Set<string>([ccDefault]);
  if (payload.adminEmail?.trim()) {
    ccRecipients.add(payload.adminEmail.trim());
  }

  const userResult = await sendResendEmail({
    to: [payload.userEmail],
    cc: Array.from(ccRecipients),
    subject: "Cont ERP Mobile activat — date autentificare",
    text: body,
  });

  if (!userResult.ok) {
    return { sent: false, details: userResult.error ?? "Eroare Resend" };
  }

  if (payload.adminEmail?.trim()) {
    const adminBody = `
Bună,

Utilizatorul ${payload.userFullName} și-a confirmat emailul și contul ERP Mobile este acum activ.

Email: ${payload.userEmail}
CNP: ${payload.userCNP}
Telefon: ${payload.userPhone || "-"}

Utilizatorul a primit datele de autentificare pe email.

Cu stimă,
ERP Mobile
`.trim();

    const adminResult = await sendResendEmail({
      to: [payload.adminEmail.trim()],
      subject: "Utilizator activat în ERP Mobile",
      text: adminBody,
    });

    if (!adminResult.ok) {
      return {
        sent: true,
        details: `Email trimis utilizatorului, dar notificarea admin a eșuat: ${adminResult.error}`,
      };
    }
  }

  return {
    sent: true,
    details: `Email de activare trimis utilizatorului (CC: ${Array.from(ccRecipients).join(", ")}).`,
  };
}

export async function sendEmailChangeVerification(
  payload: {
    userEmail: string;
    userFullName: string;
    verificationLink: string | null;
    adminEmail: string;
    adminFullName: string;
  },
): Promise<{ sent: boolean; details: string }> {
  if (!payload.verificationLink) {
    return {
      sent: false,
      details: "Linkul de confirmare lipsește.",
    };
  }

  const userBody = `
Bună ${payload.userFullName},

Adresa de email a contului dvs. ERP Mobile a fost modificată de administrator.

Confirmați noua adresă accesând linkul:
${payload.verificationLink}

Contul rămâne inactiv până la confirmare.

Cu stimă,
Echipa Dateconta ERP
`.trim();

  const result = await sendResendEmail({
    to: [payload.userEmail],
    subject: "Confirmați noua adresă de email — ERP Mobile",
    text: userBody,
  });

  if (!result.ok) {
    return { sent: false, details: result.error ?? "Eroare Resend" };
  }

  return { sent: true, details: "Email de confirmare trimis pentru noua adresă." };
}

export async function sendConfirmationResend(
  payload: {
    userEmail: string;
    userFullName: string;
    verificationLink: string | null;
    adminEmail: string;
    adminFullName: string;
  },
): Promise<{ sent: boolean; details: string }> {
  if (!Deno.env.get("RESEND_API_KEY")) {
    const linkNote = payload.verificationLink
      ? " Linkul de confirmare a fost generat, dar nu a putut fi trimis fără RESEND_API_KEY."
      : "";
    return {
      sent: false,
      details: `Emailul nu a fost trimis: RESEND_API_KEY lipsește.${linkNote}`,
    };
  }

  if (!payload.verificationLink) {
    return {
      sent: false,
      details: "Linkul de confirmare nu a putut fi generat. Verificați Redirect URLs în Supabase Auth.",
    };
  }

  const userBody = `
Bună ${payload.userFullName},

Administratorul v-a retrimis linkul de confirmare pentru contul ERP Mobile.

Confirmați adresa de email accesând linkul:
${payload.verificationLink}

Contul nu poate fi folosit în aplicație până când confirmați emailul.

Cu stimă,
Echipa Dateconta ERP
`.trim();

  const result = await sendResendEmail({
    to: [payload.userEmail],
    subject: "Retrimiteți confirmarea emailului — ERP Mobile",
    text: userBody,
  });

  if (!result.ok) {
    return { sent: false, details: result.error ?? "Eroare Resend" };
  }

  if (payload.adminEmail) {
    await sendResendEmail({
      to: [payload.adminEmail],
      subject: "Confirmare retrimisă — ERP Mobile",
      text: `Ați retrimis linkul de confirmare către ${payload.userFullName} (${payload.userEmail}).\n\nLink (dacă utilizatorul nu primește emailul):\n${payload.verificationLink}`,
    });
  }

  return {
    sent: true,
    details: "Email de confirmare retrimis utilizatorului.",
  };
}

export async function sendPasswordChangeConfirmation(
  payload: {
    userEmail: string;
    userFullName: string;
    verificationLink: string | null;
  },
): Promise<{ sent: boolean; details: string }> {
  if (!Deno.env.get("RESEND_API_KEY")) {
    const linkNote = payload.verificationLink
      ? " Linkul de confirmare a fost generat, dar nu a putut fi trimis fără RESEND_API_KEY."
      : "";
    return {
      sent: false,
      details: `Emailul nu a fost trimis: RESEND_API_KEY lipsește.${linkNote}`,
    };
  }

  if (!payload.verificationLink) {
    return {
      sent: false,
      details: "Linkul de confirmare nu a putut fi generat. Verificați Redirect URLs în Supabase Auth.",
    };
  }

  const userBody = `
Bună ${payload.userFullName},

Parola contului dvs. ERP Mobile a fost schimbată.

Confirmați din nou adresa de email accesând linkul:
${payload.verificationLink}

Contul nu poate fi folosit în aplicație până când confirmați emailul.

Cu stimă,
Echipa Dateconta ERP
`.trim();

  const result = await sendResendEmail({
    to: [payload.userEmail],
    subject: "Confirmați emailul după schimbarea parolei — ERP Mobile",
    text: userBody,
  });

  if (!result.ok) {
    return { sent: false, details: result.error ?? "Eroare Resend" };
  }

  return {
    sent: true,
    details: "Email de confirmare trimis după schimbarea parolei.",
  };
}
