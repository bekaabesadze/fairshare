import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case en, es, fr, no
    var id: String { rawValue }
    var name: String {
        switch self {
        case .en: "English"
        case .es: "Español"
        case .fr: "Français"
        case .no: "Norsk"
        }
    }
}

struct Copy {
    var language: AppLanguage = .en

    func callAsFunction(_ english: String) -> String {
        guard language != .en else { return english }
        return Self.table[english]?[language] ?? english
    }

    func f(_ english: String, _ args: CVarArg...) -> String {
        String(format: self(english), arguments: args)
    }

    private static let table: [String: [AppLanguage: String]] = [
        "Your club’s money, clear and simple.": [.es: "El dinero de tu club, claro y sencillo.", .fr: "L’argent de votre club, clair et simple.", .no: "Klubbens penger, enkelt og oversiktlig."],
        "Get started": [.es: "Empezar", .fr: "Commencer", .no: "Kom i gang"],
        "I already have an account": [.es: "Ya tengo una cuenta", .fr: "J’ai déjà un compte", .no: "Jeg har allerede en konto"],
        "See exactly what’s left": [.es: "Mira exactamente lo que queda", .fr: "Voyez exactement ce qui reste", .no: "Se nøyaktig hva som er igjen"],
        "No more spreadsheets": [.es: "Adiós a las hojas de cálculo", .fr: "Fini les tableurs", .no: "Slutt på regneark"],
        "Snap a receipt, we read it": [.es: "Fotografía el recibo y lo leemos", .fr: "Photographiez le reçu, on le lit", .no: "Ta bilde av kvitteringen, vi leser den"],
        "Remaining": [.es: "Restante", .fr: "Restant", .no: "Igjen"],
        "Language": [.es: "Idioma", .fr: "Langue", .no: "Språk"],
        "Switch to dark mode": [.es: "Cambiar al modo oscuro", .fr: "Passer en mode sombre", .no: "Bytt til mørk modus"],
        "Switch to light mode": [.es: "Cambiar al modo claro", .fr: "Passer en mode clair", .no: "Bytt til lys modus"],

        "Back": [.es: "Atrás", .fr: "Retour", .no: "Tilbake"],
        "Step %d of 5": [.es: "Paso %d de 5", .fr: "Étape %d sur 5", .no: "Steg %d av 5"],
        "Who are you?": [.es: "¿Quién eres?", .fr: "Qui êtes-vous\u{00A0}?", .no: "Hvem er du?"],
        "I run a student organization": [.es: "Dirijo una organización estudiantil", .fr: "Je dirige une association étudiante", .no: "Jeg leder en studentorganisasjon"],
        "I work in Student Accounts": [.es: "Trabajo en Cuentas Estudiantiles", .fr: "Je travaille au service des comptes étudiants", .no: "Jeg jobber i studentregnskap"],
        "I advise an organization": [.es: "Asesoro a una organización", .fr: "J’accompagne une association", .no: "Jeg er veileder for en organisasjon"],
        "I manage FairShare": [.es: "Administro FairShare", .fr: "Je gère FairShare", .no: "Jeg administrerer FairShare"],
        "Continue": [.es: "Continuar", .fr: "Continuer", .no: "Fortsett"],
        "Sign in with your Luther email": [.es: "Inicia sesión con tu correo de Luther", .fr: "Connectez-vous avec votre e-mail Luther", .no: "Logg inn med Luther-e-posten din"],
        "Demo accounts": [.es: "Cuentas de demostración", .fr: "Comptes de démo", .no: "Demokontoer"],
        "Continue with Luther SSO": [.es: "Continuar con Luther SSO", .fr: "Continuer avec Luther SSO", .no: "Fortsett med Luther SSO"],
        "Signing in…": [.es: "Iniciando sesión…", .fr: "Connexion…", .no: "Logger inn…"],
        "Use your @%@ email address.": [.es: "Usa tu dirección de correo @%@.", .fr: "Utilisez votre adresse e-mail @%@.", .no: "Bruk e-postadressen din som slutter på @%@."],
        "We couldn’t find an account for that email. Ask your organization’s president or Student Accounts to add you.": [
            .es: "No encontramos una cuenta con ese correo. Pide al presidente de tu organización o a Cuentas Estudiantiles que te agreguen.",
            .fr: "Aucun compte ne correspond à cet e-mail. Demandez au président de votre association ou au service des comptes étudiants de vous ajouter.",
            .no: "Vi fant ingen konto for den e-posten. Be lederen i organisasjonen din eller studentregnskap om å legge deg til.",
        ],
        "Is this your organization?": [.es: "¿Es esta tu organización?", .fr: "Est-ce votre association\u{00A0}?", .no: "Er dette organisasjonen din?"],
        "You advise these organizations": [.es: "Asesoras a estas organizaciones", .fr: "Vous accompagnez ces associations", .no: "Du er veileder for disse organisasjonene"],
        "Welcome, %@": [.es: "Te damos la bienvenida, %@", .fr: "Bienvenue, %@", .no: "Velkommen, %@"],
        "Yes, that’s us": [.es: "Sí, somos nosotros", .fr: "Oui, c’est nous", .no: "Ja, det er oss"],
        "No, it’s not": [.es: "No, no es", .fr: "Non, ce n’est pas ça", .no: "Nei, det er det ikke"],
        "That’s not right": [.es: "Eso no es correcto", .fr: "Ce n’est pas correct", .no: "Det stemmer ikke"],
        "Not you?": [.es: "¿No eres tú?", .fr: "Ce n’est pas vous\u{00A0}?", .no: "Ikke deg?"],
        "Read-only": [.es: "Solo lectura", .fr: "Lecture seule", .no: "Kun lesetilgang"],
        "%d organizations": [.es: "%d organizaciones", .fr: "%d associations", .no: "%d organisasjoner"],

        "Know the moment money moves": [.es: "Entérate en cuanto se mueva el dinero", .fr: "Sachez dès que l’argent bouge", .no: "Få vite det med en gang pengene flytter seg"],
        "$52.00 approved": [.es: "$52.00 aprobados", .fr: "$52.00 approuvés", .no: "$52.00 godkjent"],
        "Luther Book Shop · Prizes": [.es: "Luther Book Shop · Premios", .fr: "Luther Book Shop · Prix", .no: "Luther Book Shop · Premier"],
        "One more document needed": [.es: "Falta un documento", .fr: "Un document de plus est requis", .no: "Ett dokument til trengs"],
        "$150.00 added to your budget": [.es: "$150.00 añadidos a tu presupuesto", .fr: "$150.00 ajoutés à votre budget", .no: "$150.00 lagt til i budsjettet"],
        "Student Accounts": [.es: "Cuentas Estudiantiles", .fr: "Comptes étudiants", .no: "Studentregnskap"],
        "Annual funding request is open": [.es: "La solicitud anual de fondos está abierta", .fr: "La demande de financement annuelle est ouverte", .no: "Den årlige søknaden om midler er åpen"],
        "Due December 11": [.es: "Vence el 11 de diciembre", .fr: "À rendre le 11 décembre", .no: "Frist 11. desember"],
        "now": [.es: "ahora", .fr: "maintenant", .no: "nå"],
        "Turn on notifications": [.es: "Activar notificaciones", .fr: "Activer les notifications", .no: "Slå på varsler"],
        "Not now": [.es: "Ahora no", .fr: "Pas maintenant", .no: "Ikke nå"],

        "You’re all set": [.es: "Todo listo", .fr: "Tout est prêt", .no: "Alt er klart"],
        "See what’s left": [.es: "Mira lo que queda", .fr: "Voyez ce qui reste", .no: "Se hva som er igjen"],
        "Snap a receipt": [.es: "Fotografía un recibo", .fr: "Photographiez un reçu", .no: "Ta bilde av en kvittering"],
        "Ask FairShare": [.es: "Pregúntale a FairShare", .fr: "Demandez à FairShare", .no: "Spør FairShare"],
        "Start using FairShare": [.es: "Empezar a usar FairShare", .fr: "Commencer avec FairShare", .no: "Begynn å bruke FairShare"],

        "You’re all set, %@": [.es: "Todo listo, %@", .fr: "Tout est prêt, %@", .no: "Alt er klart, %@"],
        "Here’s %@ today.": [.es: "Así está %@ hoy.", .fr: "Voici %@ aujourd’hui.", .no: "Slik står det til med %@ i dag."],
        "Here’s what you advise today.": [.es: "Así están tus organizaciones hoy.", .fr: "Voici vos associations aujourd’hui.", .no: "Slik står organisasjonene dine i dag."],
        "Here’s every organization today.": [.es: "Así están todas las organizaciones hoy.", .fr: "Voici toutes les associations aujourd’hui.", .no: "Slik står alle organisasjonene i dag."],
        "Safe to spend": [.es: "Libre para gastar", .fr: "Disponible", .no: "Kan brukes"],
        "After pending": [.es: "Tras lo pendiente", .fr: "Hors attente", .no: "Etter ventende"],
        "Pending": [.es: "Pendiente", .fr: "En attente", .no: "Til behandling"],
        "Waiting for review": [.es: "En revisión", .fr: "En cours de revue", .no: "Venter på godkjenning"],
        "Spent": [.es: "Gastado", .fr: "Dépensé", .no: "Brukt"],
        "Approved": [.es: "Aprobado", .fr: "Approuvé", .no: "Godkjent"],

        "Let’s fix that": [.es: "Vamos a arreglarlo", .fr: "Corrigeons ça", .no: "La oss fikse det"],
        "%@ is linked to %@.": [.es: "%@ está vinculado a %@.", .fr: "%@ est associé à %@.", .no: "%@ er knyttet til %@."],
        "%@ access": [.es: "acceso de %@", .fr: "accès %@", .no: "%@-tilgang"],
        " and ": [.es: " y ", .fr: " et ", .no: " og "],
        "Ask Student Accounts to fix it": [.es: "Pedir a Cuentas Estudiantiles que lo corrija", .fr: "Demander au service des comptes étudiants de corriger", .no: "Be studentregnskap om å rette det"],
        "Ask the FairShare admin to fix it": [.es: "Pedir al administrador de FairShare que lo corrija", .fr: "Demander à l’administrateur FairShare de corriger", .no: "Be FairShare-administratoren om å rette det"],
        "Sent to Student Accounts": [.es: "Enviado a Cuentas Estudiantiles", .fr: "Envoyé au service des comptes étudiants", .no: "Sendt til studentregnskap"],
        "Sent to the FairShare admin": [.es: "Enviado al administrador de FairShare", .fr: "Envoyé à l’administrateur FairShare", .no: "Sendt til FairShare-administratoren"],
        "Use a different email": [.es: "Usar otro correo", .fr: "Utiliser un autre e-mail", .no: "Bruk en annen e-post"],
        "You can sign in once they’ve fixed it.": [.es: "Podrás iniciar sesión cuando lo hayan corregido.", .fr: "Vous pourrez vous connecter une fois que ce sera corrigé.", .no: "Du kan logge inn når det er rettet."],
        "Done": [.es: "Listo", .fr: "Terminé", .no: "Ferdig"],
    ]
}

private struct CopyKey: EnvironmentKey {
    static let defaultValue = Copy()
}

extension EnvironmentValues {
    var copy: Copy {
        get { self[CopyKey.self] }
        set { self[CopyKey.self] = newValue }
    }
}
