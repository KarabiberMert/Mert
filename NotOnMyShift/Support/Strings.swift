import Foundation

/// Ekranda görünen tüm metinler tek yerde.
///
/// Kaynak dil İngilizce; `tr` ve `es` çeviridir. `defaultValue` verildiği için
/// bir dil dosyası eksik ya da bozuk olsa bile metin İngilizce görünür,
/// anahtar görünmez.
///
/// İki kural:
/// - **Çoğul eki olan cümle yazma.** `.stringsdict` kurmak yerine her dilde
///   1 ve 38 için aynı çalışan bir kalıp seç ("%lld more to go").
/// - **Ekleri yer tutucuya yapıştırma.** Türkçe ünlü uyumu bozulur
///   ("%@lik" → "2 saatlik" ama "3 günlik"). Ayrı sözcük kullan.
enum L {

    // MARK: - Biçim (dile bağlı para ve sayı)

    /// Ondalık ve binlik ayracını belirleyen yerel.
    static var numberLocaleIdentifier: String {
        String(localized: "format.numberLocale", defaultValue: "en_US",
               comment: "Number formatting locale for this language, e.g. en_US, tr_TR, es_ES")
    }
    /// Para kalıbı. `{amount}` yer tutucusu zorunlu; simgenin yerini ve
    /// aradaki boşluğu bu kalıp belirler.
    static var currencyPattern: String {
        String(localized: "format.currencyPattern", defaultValue: "${amount}",
               comment: "Currency layout. Keep the {amount} placeholder. e.g. ${amount}, {amount} ₺, {amount} €")
    }
    static var scaleE3: String {
        String(localized: "format.scale.e3", defaultValue: "K", comment: "Abbreviation for thousand")
    }
    static var scaleE6: String {
        String(localized: "format.scale.e6", defaultValue: "M", comment: "Abbreviation for million")
    }
    static var scaleE9: String {
        String(localized: "format.scale.e9", defaultValue: "B", comment: "Abbreviation for 10^9")
    }
    static var scaleE12: String {
        String(localized: "format.scale.e12", defaultValue: "T", comment: "Abbreviation for 10^12")
    }
    static var scaleE15: String {
        String(localized: "format.scale.e15", defaultValue: "Q", comment: "Abbreviation for 10^15")
    }
    static var durationNone: String {
        String(localized: "duration.none", defaultValue: "no time at all", comment: "Zero duration")
    }

    // MARK: - Dükkân

    static var tapToSell: String {
        String(localized: "shop.tapHint", defaultValue: "Tap the counter to make a sale.", comment: "Age 0 hint")
    }
    static var shopAccessibility: String {
        String(localized: "shop.a11y", defaultValue: "The shop. Tap to sell a coffee.", comment: "Accessibility label for the building")
    }

    // MARK: - Sektörler (kat = sektör)

    /// Cümle içinde geçen adı: "Köşe Fırın açıldı".
    static func sectorName(_ id: String) -> String {
        switch id {
        case "coffee": String(localized: "sector.coffee.name", defaultValue: "Pop's Coffee", comment: "Sector name in a sentence")
        case "bakery": String(localized: "sector.bakery.name", defaultValue: "Corner Bakery", comment: "Sector name in a sentence")
        default: String(localized: "sector.unknown.name", defaultValue: "A new trade", comment: "Fallback sector name")
        }
    }

    /// Emaye tabelada göründüğü hâliyle. Kod büyük harfe çevirmez —
    /// yerele bağlı çevirme İngilizce adları bozardı (Willie → WİLLİE).
    static func sectorSign(_ id: String) -> String {
        switch id {
        case "coffee": String(localized: "sector.coffee.sign", defaultValue: "POP'S COFFEE", comment: "Text on the enamel sign, exactly as it should appear")
        case "bakery": String(localized: "sector.bakery.sign", defaultValue: "CORNER BAKERY", comment: "Text on the enamel sign, exactly as it should appear")
        default: String(localized: "sector.unknown.sign", defaultValue: "OPEN FOR BUSINESS", comment: "Fallback sign text")
        }
    }

    /// Elle satış butonu — sektöre göre değişir, ton kaybolmasın.
    static func sectorSell(_ id: String) -> String {
        switch id {
        case "coffee": String(localized: "sector.coffee.sell", defaultValue: "Sell a coffee", comment: "Manual production button")
        case "bakery": String(localized: "sector.bakery.sell", defaultValue: "Sell a loaf", comment: "Manual production button")
        default: String(localized: "sector.unknown.sell", defaultValue: "Make a sale", comment: "Fallback manual production button")
        }
    }

    // MARK: - Katlar

    static var openNextFloor: String {
        String(localized: "floor.open", defaultValue: "Open the floor above", comment: "Unlock the next floor")
    }
    /// "Corner Bakery moves in"
    static func floorOpensSector(_ name: String) -> String {
        String(localized: "floor.opensSector", defaultValue: "\(name) moves in", comment: "Which sector the next floor will hold")
    }
    static var buildingFull: String {
        String(localized: "floor.allOpen", defaultValue: "Every floor is yours. The building is full.", comment: "No sectors left")
    }
    /// Çoğul eki yok.
    static func floorNumber(_ number: Int) -> String {
        String(localized: "floor.number", defaultValue: "Floor \(number)", comment: "Floor label. Must read correctly for 1 as well as 8.")
    }
    static var groundFloor: String {
        String(localized: "floor.ground", defaultValue: "Ground floor", comment: "The first floor")
    }
    static var tabBuilding: String {
        String(localized: "tab.building", defaultValue: "Building", comment: "Panel tab")
    }

    /// "Corner Bakery is open"
    static func newFloorTitle(_ name: String) -> String {
        String(localized: "newFloor.title", defaultValue: "\(name) is open", comment: "Floor unlocked celebration heading")
    }
    static var newFloorBody: String {
        String(localized: "newFloor.body", defaultValue: "A new floor, a new trade. It starts empty — hire, kit it out, and this one will run without you too.",
               comment: "What opening a floor means")
    }
    static var newFloorAction: String {
        String(localized: "newFloor.action", defaultValue: "Let's go", comment: "Dismiss the floor celebration")
    }

    // MARK: - Kadro (isimler ve huylar dile göre değişir)

    /// Kimlik kayıtta saklanır, isim dilden gelir. Böylece oyuncu dili
    /// değiştirince mevcut kadro da yeni dilde görünür.
    static func staffName(_ id: String) -> String {
        switch id {
        case "quick": String(localized: "staff.quick.name", defaultValue: "Rosie", comment: "Crew member name")
        case "opener": String(localized: "staff.opener.name", defaultValue: "Danny", comment: "Crew member name")
        case "chatty": String(localized: "staff.chatty.name", defaultValue: "Maggie", comment: "Crew member name")
        case "veteran": String(localized: "staff.veteran.name", defaultValue: "Walter", comment: "Crew member name")
        case "phone": String(localized: "staff.phone.name", defaultValue: "Theo", comment: "Crew member name")
        case "artist": String(localized: "staff.artist.name", defaultValue: "Priya", comment: "Crew member name")
        case "baker": String(localized: "staff.baker.name", defaultValue: "Ines", comment: "Crew member name")
        case "kneader": String(localized: "staff.kneader.name", defaultValue: "Gus", comment: "Crew member name")
        case "froster": String(localized: "staff.froster.name", defaultValue: "Marion", comment: "Crew member name")
        case "night": String(localized: "staff.night.name", defaultValue: "Sam", comment: "Crew member name")
        case "apprentice": String(localized: "staff.apprentice.name", defaultValue: "Bo", comment: "Crew member name")
        default: String(localized: "staff.unknown.name", defaultValue: "New hire", comment: "Fallback for a crew id this build does not know")
        }
    }

    static func staffTrait(_ id: String) -> String {
        switch id {
        case "quick": String(localized: "staff.quick.trait", defaultValue: "Fast, but mixes up the orders.", comment: "Crew member quirk")
        case "opener": String(localized: "staff.opener.trait", defaultValue: "Opens at six. Cannot wake up at six.", comment: "Crew member quirk")
        case "chatty": String(localized: "staff.chatty.trait", defaultValue: "Turns every order into a conversation.", comment: "Crew member quirk")
        case "veteran": String(localized: "staff.veteran.trait", defaultValue: "Slow, but has not got one wrong in thirty years.", comment: "Crew member quirk")
        case "phone": String(localized: "staff.phone.trait", defaultValue: "Never off the phone, somehow never behind.", comment: "Crew member quirk")
        case "artist": String(localized: "staff.artist.trait", defaultValue: "Working on latte art. Currently drawing kidneys.", comment: "Crew member quirk")
        case "baker": String(localized: "staff.baker.trait", defaultValue: "Knows the oven better than the thermostat does.", comment: "Crew member quirk")
        case "kneader": String(localized: "staff.kneader.trait", defaultValue: "Talks to the dough. The dough behaves.", comment: "Crew member quirk")
        case "froster": String(localized: "staff.froster.trait", defaultValue: "Every cake leaves straight. Every one.", comment: "Crew member quirk")
        case "night": String(localized: "staff.night.trait", defaultValue: "Starts at three in the morning and seems happy about it.", comment: "Crew member quirk")
        case "apprentice": String(localized: "staff.apprentice.trait", defaultValue: "Still measuring everything twice. Learning fast.", comment: "Crew member quirk")
        default: String(localized: "staff.unknown.trait", defaultValue: "Keeps to themselves.", comment: "Fallback quirk")
        }
    }

    // MARK: - Kasa

    static var cash: String {
        String(localized: "cash.label", defaultValue: "Cash", comment: "Money counter heading")
    }
    static var workingByHand: String {
        String(localized: "cash.byHand", defaultValue: "For now you make every coffee yourself.", comment: "Age 0 explanation")
    }
    /// "$1.4 per second" — maaş düşülmüş net.
    static func perSecond(_ amount: String) -> String {
        String(localized: "cash.perSecond", defaultValue: "\(amount) per second", comment: "Passive income line, after wages")
    }
    /// Tek yer tutucu: sözcük sırası dile kalsın diye brüt ve maaş ayrı anahtarlar.
    static func grossAmount(_ amount: String) -> String {
        String(localized: "cash.gross", defaultValue: "\(amount) gross", comment: "Production before wages")
    }
    static func wagesAmount(_ amount: String) -> String {
        String(localized: "cash.wages", defaultValue: "\(amount) wages", comment: "Wage cost per second")
    }

    // MARK: - Eylemler

    static var hireStaff: String {
        String(localized: "action.hire", defaultValue: "Hire someone", comment: "Hire button")
    }
    static var upgradeWarehouse: String {
        String(localized: "action.upgradeWarehouse", defaultValue: "Grow the store room", comment: "Offline capacity upgrade")
    }
    static var staffFull: String {
        String(localized: "action.staffFull", defaultValue: "No room behind the counter for anyone else.", comment: "Crew is full")
    }
    /// Çoğul eki yok: 1 ve 38 için aynı çalışır.
    static func coffeesToGo(_ count: Int) -> String {
        String(localized: "action.coffeesToGo", defaultValue: "\(count) more to go",
               comment: "Manual sales still needed. Must read correctly for 1 as well as 38.")
    }

    // MARK: - Şeritler

    static var tabCrew: String {
        String(localized: "tab.crew", defaultValue: "Crew", comment: "Panel tab")
    }
    static var tabEquipment: String {
        String(localized: "tab.equipment", defaultValue: "Equipment", comment: "Panel tab")
    }
    static var tabBranches: String {
        String(localized: "tab.branches", defaultValue: "Branches", comment: "Panel tab")
    }

    // MARK: - Ekipman

    static func equipmentName(_ id: String) -> String {
        switch id {
        case "grinder": String(localized: "equipment.grinder.name", defaultValue: "Grinder", comment: "Equipment name")
        case "machine": String(localized: "equipment.machine.name", defaultValue: "Espresso machine", comment: "Equipment name")
        case "milk": String(localized: "equipment.milk.name", defaultValue: "Milk station", comment: "Equipment name")
        case "oven": String(localized: "equipment.oven.name", defaultValue: "Deck oven", comment: "Equipment name")
        case "mixer": String(localized: "equipment.mixer.name", defaultValue: "Spiral mixer", comment: "Equipment name")
        case "case": String(localized: "equipment.case.name", defaultValue: "Display case", comment: "Equipment name")
        default: String(localized: "equipment.unknown.name", defaultValue: "New kit", comment: "Fallback equipment name")
        }
    }

    static func equipmentNote(_ id: String) -> String {
        switch id {
        case "grinder": String(localized: "equipment.grinder.note", defaultValue: "Fresher grounds, faster shots.", comment: "What the equipment does")
        case "machine": String(localized: "equipment.machine.note", defaultValue: "Two groups instead of one.", comment: "What the equipment does")
        case "milk": String(localized: "equipment.milk.note", defaultValue: "No more queueing for the steam wand.", comment: "What the equipment does")
        case "oven": String(localized: "equipment.oven.note", defaultValue: "Even heat, three decks, no cold corners.", comment: "What the equipment does")
        case "mixer": String(localized: "equipment.mixer.note", defaultValue: "Kneads in ten minutes what took an hour.", comment: "What the equipment does")
        case "case": String(localized: "equipment.case.note", defaultValue: "Nothing goes stale on the shelf any more.", comment: "What the equipment does")
        default: String(localized: "equipment.unknown.note", defaultValue: "Does its job quietly.", comment: "Fallback equipment note")
        }
    }

    /// Çoğul eki yok.
    static func equipmentLevel(_ level: Int) -> String {
        String(localized: "equipment.level", defaultValue: "Level \(level)", comment: "Owned equipment level")
    }
    static var equipmentMaxed: String {
        String(localized: "equipment.maxed", defaultValue: "Fully upgraded", comment: "Equipment at last level")
    }
    /// "Output ×1.45"
    static func equipmentOutput(_ multiplier: String) -> String {
        String(localized: "equipment.output", defaultValue: "Output ×\(multiplier)", comment: "Production multiplier from equipment")
    }

    // MARK: - Şubeler

    static var branchOpen: String {
        String(localized: "branch.open", defaultValue: "Open a branch", comment: "Open a new branch")
    }
    /// Çoğul eki yok: 1 ve 4 için aynı çalışmalı.
    static func branchesRunning(_ count: Int) -> String {
        String(localized: "branch.count", defaultValue: "\(count) open", comment: "How many branches are running. Must read correctly for 1 as well.")
    }
    static var branchInherits: String {
        String(localized: "branch.inherits", defaultValue: "A new branch copies your crew and your kit. Nothing to set up twice.", comment: "One-tap copy explanation")
    }
    static var branchesFull: String {
        String(localized: "branch.maxed", defaultValue: "Every unit on this floor is yours.", comment: "Floor is full")
    }

    // MARK: - Depo

    /// Ek yok: süre ayrı bir sözcük olarak durur.
    static func warehouseHolds(_ duration: String) -> String {
        String(localized: "warehouse.holds", defaultValue: "While you are away it collects up to \(duration) of production.",
               comment: "Warehouse capacity. Do not glue suffixes onto the placeholder.")
    }

    // MARK: - Çağ 1 anı

    static func startedWork(_ name: String) -> String {
        String(localized: "firstHire.title", defaultValue: "\(name) started work", comment: "First hire celebration heading")
    }
    static var firstHireBody: String {
        String(localized: "firstHire.body", defaultValue: "Coffee sells now even when you are not here. Close the app and the store room keeps filling.",
               comment: "The moment offline earnings open up")
    }
    static var firstHireAction: String {
        String(localized: "firstHire.action", defaultValue: "Good", comment: "Dismiss the celebration")
    }

    // MARK: - Olaylar

    static func eventTitle(_ id: String) -> String {
        switch id {
        case "viral": String(localized: "event.viral.title", defaultValue: "A video took off", comment: "Event heading")
        case "festival": String(localized: "event.festival.title", defaultValue: "There is a festival on the street", comment: "Event heading")
        case "supplier": String(localized: "event.supplier.title", defaultValue: "The supplier put the price up", comment: "Event heading")
        case "inspection": String(localized: "event.inspection.title", defaultValue: "Health inspection", comment: "Event heading")
        case "apprentice": String(localized: "event.apprentice.title", defaultValue: "Someone wants to learn", comment: "Event heading")
        default: String(localized: "event.unknown.title", defaultValue: "Something came up", comment: "Fallback event heading")
        }
    }

    static func eventBody(_ id: String) -> String {
        switch id {
        case "viral": String(localized: "event.viral.body", defaultValue: "Someone filmed your counter and half the town has seen it.", comment: "Event description")
        case "festival": String(localized: "event.festival.body", defaultValue: "They closed the road. Everyone is walking past your door.", comment: "Event description")
        case "supplier": String(localized: "event.supplier.body", defaultValue: "Same beans, new invoice.", comment: "Event description")
        case "inspection": String(localized: "event.inspection.body", defaultValue: "Everything is fine. The paperwork is not.", comment: "Event description")
        case "apprentice": String(localized: "event.apprentice.body", defaultValue: "A kid keeps coming by and asking questions.", comment: "Event description")
        default: String(localized: "event.unknown.body", defaultValue: "It needs a decision, and only one.", comment: "Fallback event description")
        }
    }

    static func eventChoice(_ eventID: String, _ choiceID: String) -> String {
        switch "\(eventID).\(choiceID)" {
        case "viral.ride": String(localized: "event.viral.ride", defaultValue: "Ride the wave", comment: "Event choice")
        case "viral.cashIn": String(localized: "event.viral.cashIn", defaultValue: "Sell the moment", comment: "Event choice")
        case "festival.stayOpen": String(localized: "event.festival.stayOpen", defaultValue: "Stay open late", comment: "Event choice")
        case "festival.sellStall": String(localized: "event.festival.sellStall", defaultValue: "Rent out a stall", comment: "Event choice")
        case "supplier.payUp": String(localized: "event.supplier.payUp", defaultValue: "Just pay it", comment: "Event choice")
        case "supplier.switchBeans": String(localized: "event.supplier.switchBeans", defaultValue: "Switch suppliers", comment: "Event choice")
        case "inspection.payFine": String(localized: "event.inspection.payFine", defaultValue: "Pay the fine", comment: "Event choice")
        case "inspection.closeUp": String(localized: "event.inspection.closeUp", defaultValue: "Close for the afternoon", comment: "Event choice")
        case "apprentice.teachThem": String(localized: "event.apprentice.teachThem", defaultValue: "Teach them", comment: "Event choice")
        default: String(localized: "event.unknown.choice", defaultValue: "Deal with it", comment: "Fallback event choice")
        }
    }

    static var eventDismiss: String {
        String(localized: "event.dismiss", defaultValue: "Not now", comment: "Close the event without deciding")
    }
    /// "for 30 minutes"
    static func eventLasting(_ duration: String) -> String {
        String(localized: "event.lasting", defaultValue: "for \(duration)", comment: "How long an event effect lasts")
    }
    /// "$120 now"
    static func eventNow(_ amount: String) -> String {
        String(localized: "event.now", defaultValue: "\(amount) now", comment: "Instant money from an event")
    }
    /// "12 minutes left"
    static func eventRemaining(_ duration: String) -> String {
        String(localized: "event.remaining", defaultValue: "\(duration) left", comment: "Time left on an active event effect")
    }

    // MARK: - Rakipler

    static var marketTitle: String {
        String(localized: "market.title", defaultValue: "Market share", comment: "Market section heading")
    }
    static var marketYou: String {
        String(localized: "market.you", defaultValue: "You", comment: "The player's slice of the market")
    }
    static var marketBlocked: String {
        String(localized: "market.blocked", defaultValue: "The competition took the next unit. Invest and your share comes back.",
               comment: "Why a branch cannot be opened. Must read as a delay, never as a loss.")
    }
    /// Çoğul eki yok.
    static func marketSlots(_ count: Int) -> String {
        String(localized: "market.slots", defaultValue: "Units unlocked: \(count)", comment: "How many branch slots the share allows")
    }

    static func competitorName(_ id: String) -> String {
        switch id {
        case "cedar": String(localized: "competitor.cedar.name", defaultValue: "Cedar Holdings", comment: "Rival company name")
        case "mill": String(localized: "competitor.mill.name", defaultValue: "Grindhouse Group", comment: "Rival company name")
        case "percolate": String(localized: "competitor.percolate.name", defaultValue: "Percolate", comment: "Rival company name")
        default: String(localized: "competitor.unknown.name", defaultValue: "Someone else", comment: "Fallback rival name")
        }
    }

    static func competitorQuip(_ id: String) -> String {
        switch id {
        case "cedar": String(localized: "competitor.cedar.quip", defaultValue: "Their founder mentions his father in every interview.", comment: "Rival company joke")
        case "mill": String(localized: "competitor.mill.quip", defaultValue: "Forty branches. Thirty-nine look identical.", comment: "Rival company joke")
        case "percolate": String(localized: "competitor.percolate.quip", defaultValue: "An app-first coffee experience, whatever that means.", comment: "Rival company joke")
        default: String(localized: "competitor.unknown.quip", defaultValue: "Quietly opening shops somewhere.", comment: "Fallback rival joke")
        }
    }

    // MARK: - Dönüş özeti

    static var welcomeBack: String {
        String(localized: "offline.title", defaultValue: "You are back", comment: "Offline summary heading")
    }
    static func youWereAway(_ duration: String) -> String {
        String(localized: "offline.away", defaultValue: "You were away for \(duration).", comment: "Time spent away")
    }
    static var warehouseFilled: String {
        String(localized: "offline.full", defaultValue: "The store room filled up and the rest went to waste. A bigger one runs longer.",
               comment: "Capacity overflowed")
    }
    static var continueAction: String {
        String(localized: "offline.continue", defaultValue: "Carry on", comment: "Dismiss the summary")
    }

    // MARK: - Uyarılar

    static var notEnoughMoney: String {
        String(localized: "error.funds", defaultValue: "Not enough money", comment: "Insufficient funds")
    }
    static var saveRecovered: String {
        String(localized: "save.recovered", defaultValue: "The save file was damaged and was restored from the backup.", comment: "Recovered from backup")
    }
    static var saveFailed: String {
        String(localized: "save.failed", defaultValue: "Could not write the save file. Check there is space on the device.", comment: "Save error")
    }
    static var bootFailed: String {
        String(localized: "boot.failed", defaultValue: "The game could not start", comment: "Boot failure heading")
    }

    // MARK: - Geliştirme (yalnızca DEBUG)

    static var engine: String {
        String(localized: "engine.title", defaultValue: "Engine", comment: "Diagnostics section")
    }
    static var totalPlayed: String {
        String(localized: "engine.played", defaultValue: "Time processed", comment: "Total advanced seconds")
    }
    static var manualSales: String {
        String(localized: "engine.manualSales", defaultValue: "Hand sales", comment: "Manual sale count")
    }
    static var lifetime: String {
        String(localized: "engine.lifetime", defaultValue: "Earned in total", comment: "Lifetime earnings")
    }
    static var startOver: String {
        String(localized: "engine.startOver", defaultValue: "Start over", comment: "Wipe the save")
    }
}
