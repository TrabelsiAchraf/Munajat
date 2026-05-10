//
//  AdhkarType.swift
//  Adhkar
//
//  Created by Achraf Trabelsi on 18/04/2025.
//

import SwiftUI

enum AdhkarType: String, Codable, Hashable {
    case wearingNewClothes
    case wearingClothes
    case wakeUp
    case enterBathroom
    case removingClothes
    case duaForSomeoneWearingNew
    case afterWudu
    case beforeWudu
    case leaveBathroom
    case sujudTilawa
    case betweenTwoSujood
    case sujud
    case afterLastTashahhud
    case salawatAfterTashahhud
    case tashahhud
    case morningAdhkar
    case istikharahPrayer
    case afterPrayerAdhkar
    case duaWhenTurningAtNight
    case sleepAdhkar
    case eveningAdhkar
    case qunootWitr
    case dreamReaction
    case nightFear
    case distress
    case sadnessWorry
    case afterWitrAdhkar
    case goingToMosque
    case enteringHouse
    case leavingHouse
    case adhanAdhkar
    case leavingMosque
    case enteringMosque
    case standingFromRuku
    case ruku
    case openingDua
    case againstEnemy
    case fearUnjustRuler
    case meetingEnemy
    case debtRelief
    case waswasahFaith
    case fearPeople
    case repentanceAfterSin
    case hardMatter
    case waswasahPrayer
    case whenSeeingAfflicted
    case anger
    case beforeIntercourse
    case replyForgiveness
    case gatheringExpiation
    case whatToSayInGathering
    case replyLoveForAllah
    case protectionFromDajjal
    case thanksForKindness
    case residentToTraveler
    case travelerToResident
    case ifMountStumbles
    case whenStayingSomewhere
    case travelerAtSahar
    case tasbihWhileTraveling
    case virtueOfSalatOnProphet
    case reactionToGoodOrBadNews
    case returnFromTravel
    case afterRain
    case whenRainFalls
    case askingForRain
    case iftarDua
    case moonSighting
    case duaForClearSky
    case guestForHost
    case afterMeal
    case beforeMeal
    case fastingWithFoodButNoIftar
    case iftarAtSomeoneHome
    case duaForDrinkOrDesire
    case sneezeDua
    case seeingDatesFirstTime
    case fastingResponseToInsult
    case marriageAndRidePurchase
    case duaForMarriedPerson
    case responseToSneezingKafir
    case newbornGreetingAndReply
    case duaInUnwantedSituation
    case expelShaytanWhispers
    case virtueVisitingSick
    case duaForSickWhenVisited
    case protectionDuaForChildren
    case calamityDua
    case finalMomentsDua
    case desperateSickDua
    case initiateSalam
    case replySalamToNonMuslim
    case duaWhenHearingAnimals
    case responseToPraise
    case duaForOneYouInsulted
    case duaDogBarkAtNight
    case takbirAtBlackStone
    case talbiyahForIhram
    case responseToPraiseMentioned
    case whatToSayWhenFrightened
    case whatToSayWhenSlaughtering
    case whatToSayAgainstDevils
    case howProphetDidTasbih
    case virtueOfDhikrForms
    case forgivenessAndRepentance
    case generalGoodEtiquette
    case duaaWhenSomeoneOffersWealth
    case duaaForCreditorWhenRepaying
    case duaaFearOfShirk
    case duaaForRiding
    case duaaForSuperstitionAversion
    case duaaForSomeoneWhoBlessedYou
    case duaaEnteringMarket
    case duaaEnteringVillageOrTown
    case duaaForTravel
    case duaaBetweenRuknAndBlackStone
    case duaaAtSafaAndMarwah
    case duaaOnArafatDay
    case duaaOfAmazementAndJoy
    case takbeerWhileThrowingStones
    case dhikrAtMasharAlHaram
    case duaaIfYouFearToHarmWithEye
    case duaaWhenFeelingPain
    case whatToSayWhenYouReceiveGoodNews
    case duaaForDeadInJanazah
    case duaaForObligatoryPrayerOnDead
    case duaaWhenClosingDeadEyes
    case duaaAfterBurial
    case duaaWhenPuttingInGrave
    case duaaForCondolence
    case duaaForThunder
    case duaaForWind
    case duaaVisitingGraves
    
    @ViewBuilder
    var image: some View {
        switch self {
        case .wearingClothes: Image(systemName: "tshirt")
        case .wearingNewClothes: Image(systemName: "tshirt.fill")
        case .wakeUp: Image(systemName: "bed.double.fill")
        case .enterBathroom, .leaveBathroom: Image(systemName: "toilet")
        case .removingClothes: Image(systemName: "tshirt")
        case .duaForSomeoneWearingNew: Image(systemName: "gift")
        case .afterWudu: Image(systemName: "drop")
        case .beforeWudu: Image(systemName: "hands.sparkles")
        case .sujudTilawa: Image(systemName: "book.closed")
        case .betweenTwoSujood: Image(systemName: "chair.fill")
        case .sujud: Image(systemName: "arrow.down.to.line")
        case .afterLastTashahhud: Image(systemName: "figure.wave")
        case .salawatAfterTashahhud: Image(systemName: "sparkles")
        case .tashahhud: Image(systemName: "hand.point.up.fill")
        case .morningAdhkar: Image(systemName: "sun.max.fill")
        case .istikharahPrayer: Image(systemName: "questionmark.circle")
        case .afterPrayerAdhkar: Image(systemName: "hands.sparkles")
        case .duaWhenTurningAtNight: Image(systemName: "bed.double")
        case .sleepAdhkar: Image(systemName: "bed.double.fill")
        case .eveningAdhkar: Image(systemName: "moon.stars.fill")
        case .qunootWitr: Image(systemName: "person.3.sequence.fill")
        case .dreamReaction: Image(systemName: "brain.head.profile")
        case .nightFear: Image(systemName: "figure.dance")
        case .distress: Image(systemName: "cross.vial")
        case .sadnessWorry: Image(systemName: "face.dashed")
        case .afterWitrAdhkar: Image(systemName: "sparkles")
        case .goingToMosque: Image(systemName: "location.circle.fill")
        case .enteringHouse: Image(systemName: "door.left.hand.open")
        case .leavingHouse: Image(systemName: "door.right.hand.open")
        case .adhanAdhkar: Image(systemName: "dot.radiowaves.left.and.right")
        case .leavingMosque: Image(systemName: "rectangle.portrait.and.arrow.right")
        case .enteringMosque: Image(systemName: "rectangle.portrait.and.arrow.forward")
        case .standingFromRuku: Image(systemName: "figure.stand")
        case .ruku: Image(systemName: "figure.wrestling")
        case .openingDua: Image(systemName: "figure.2.arms.open")
        case .againstEnemy: Image(systemName: "figure.stand.line.dotted.figure.stand")
        case .fearUnjustRuler: Image(systemName: "crown.fill")
        case .meetingEnemy: Image(systemName: "person.3.sequence.fill")
        case .debtRelief: Image(systemName: "creditcard.fill")
        case .waswasahFaith: Image(systemName: "questionmark.circle.fill")
        case .fearPeople: Image(systemName: "exclamationmark.triangle.fill")
        case .repentanceAfterSin: Image(systemName: "figure.walk.departure")
        case .hardMatter: Image(systemName: "puzzlepiece.extension.fill")
        case .waswasahPrayer: Image(systemName: "eye.slash.circle.fill")
        case .whenSeeingAfflicted: Image(systemName: "figure.roll")
        case .anger: Image(systemName: "figure.martial.arts")
        case .beforeIntercourse: Image(systemName: "figure.2.arms.open")
        case .replyForgiveness: Image(systemName: "hand.raised.fill")
        case .gatheringExpiation: Image(systemName: "person.3.sequence.fill")
        case .whatToSayInGathering: Image(systemName: "text.bubble.fill")
        case .replyLoveForAllah: Image(systemName: "hands.sparkles")
        case .protectionFromDajjal: Image(systemName: "eye.trianglebadge.exclamationmark")
        case .thanksForKindness: Image(systemName: "hands.clap.fill")
        case .residentToTraveler: Image(systemName: "flag.fill")
        case .travelerToResident: Image(systemName: "airplane.departure")
        case .ifMountStumbles: Image(systemName: "figure.fall")
        case .whenStayingSomewhere: Image(systemName: "tent.fill")
        case .travelerAtSahar: Image(systemName: "car.fill")
        case .tasbihWhileTraveling: Image(systemName: "circle.dotted")
        case .virtueOfSalatOnProphet: Image(systemName: "staroflife.circle.fill")
        case .reactionToGoodOrBadNews: Image(systemName: "face.smiling.inverse")
        case .returnFromTravel: Image(systemName: "location.fill")
        case .afterRain: Image(systemName: "rainbow")
        case .whenRainFalls: Image(systemName: "cloud.rain")
        case .askingForRain: Image(systemName: "cloud.rain")
        case .iftarDua: Image(systemName: "takeoutbag.and.cup.and.straw.fill")
        case .moonSighting: Image(systemName: "moon.stars.fill")
        case .duaForClearSky: Image(systemName: "tree.fill")
        case .guestForHost: Image(systemName: "person.fill")
        case .afterMeal: Image(systemName: "fork.knife")
        case .beforeMeal: Image(systemName: "person.fill")
        case .fastingWithFoodButNoIftar: Image(systemName: "fork.knife.circle")
        case .iftarAtSomeoneHome: Image(systemName: "takeoutbag.and.cup.and.straw.fill")
        case .duaForDrinkOrDesire: Image(systemName: "fork.knife")
        case .sneezeDua: Image(systemName: "nose.fill")
        case .seeingDatesFirstTime: Image(systemName: "tree.fill")
        case .fastingResponseToInsult: Image(systemName: "hands.sparkles")
        case .marriageAndRidePurchase: Image(systemName: "car.fill")
        case .duaForMarriedPerson: Image(systemName: "figure.2.and.child.holdinghands")
        case .responseToSneezingKafir: Image(systemName: "face.smiling")
        case .newbornGreetingAndReply: Image(systemName: "moon.circle")
        case .duaInUnwantedSituation: Image(systemName: "person.3.fill")
        case .expelShaytanWhispers: Image(systemName: "eye.slash.circle")
        case .virtueVisitingSick: Image(systemName: "figure.wave.circle")
        case .duaForSickWhenVisited: Image(systemName: "thermometer.sun.fill")
        case .protectionDuaForChildren: Image(systemName: "person.3.sequence.fill")
        case .calamityDua: Image(systemName: "figure.fall")
        case .finalMomentsDua: Image(systemName: "waveform.path.ecg.rectangle")
        case .desperateSickDua: Image(systemName: "bed.double.circle.fill")
        case .initiateSalam: Image(systemName: "hand.wave")
        case .replySalamToNonMuslim: Image(systemName: "arrow.left.and.right.circle")
        case .duaWhenHearingAnimals: Image(systemName: "pawprint.fill")
        case .responseToPraise: Image(systemName: "sparkles.rectangle.stack")
        case .duaForOneYouInsulted: Image(systemName: "exclamationmark.bubble")
        case .duaDogBarkAtNight: Image(systemName: "pawprint")
        case .takbirAtBlackStone: Image(systemName: "cube") // or "kaaba" if custom SF symbol available
        case .talbiyahForIhram: Image(systemName: "person.crop.circle.badge.checkmark")
        case .responseToPraiseMentioned: Image(systemName: "gift.fill")
        case .whatToSayWhenFrightened: Image(systemName: "face.dashed")
        case .whatToSayWhenSlaughtering: Image(systemName: "scissors")
        case .whatToSayAgainstDevils: Image(systemName: "tornado")
        case .howProphetDidTasbih: Image(systemName: "hands.sparkles")
        case .virtueOfDhikrForms: Image(systemName: "circle.grid.cross.fill")
        case .forgivenessAndRepentance: Image(systemName: "circle.dashed.inset.filled")
        case .generalGoodEtiquette: Image(systemName: "heart.text.square")
        case .duaaWhenSomeoneOffersWealth: Image(systemName: "gift")
        case .duaaForCreditorWhenRepaying: Image(systemName: "hand.raised.fill")
        case .duaaFearOfShirk: Image(systemName: "hands.clap.fill")
        case .duaaForRiding: Image(systemName: "car.fill")
        case .duaaForSuperstitionAversion: Image(systemName: "face.smiling.inverse")
        case .duaaForSomeoneWhoBlessedYou: Image(systemName: "hands.sparkles")
        case .duaaEnteringMarket: Image(systemName: "building.2.crop.circle")
        case .duaaEnteringVillageOrTown: Image(systemName: "building.columns")
        case .duaaForTravel: Image(systemName: "car.side.fill")
        case .duaaBetweenRuknAndBlackStone: Image(systemName: "circle.hexagongrid.fill")
        case .duaaAtSafaAndMarwah: Image(systemName: "triangle")
        case .duaaOnArafatDay: Image(systemName: "mountain.2")
        case .duaaOfAmazementAndJoy: Image(systemName: "figure.stand")
        case .takbeerWhileThrowingStones: Image(systemName: "hexagon.fill")
        case .dhikrAtMasharAlHaram: Image(systemName: "figure.wave.circle")
        case .duaaIfYouFearToHarmWithEye: Image(systemName: "eye.slash")
        case .duaaWhenFeelingPain: Image(systemName: "figure.arms.open")
        case .whatToSayWhenYouReceiveGoodNews: Image(systemName: "face.smiling")
        case .duaaForDeadInJanazah: Image(systemName: "person.3.sequence")
        case .duaaForObligatoryPrayerOnDead: Image(systemName: "person.3.sequence.fill")
        case .duaaWhenClosingDeadEyes: Image(systemName: "eye.slash.circle")
        case .duaaAfterBurial: Image(systemName: "hands.clap")
        case .duaaWhenPuttingInGrave: Image(systemName: "hands.and.sparkles")
        case .duaaForCondolence: Image(systemName: "figure.2.left.holdinghands")
        case .duaaForThunder: Image(systemName: "cloud.bolt.rain")
        case .duaaForWind: Image(systemName: "wind")
        case .duaaVisitingGraves: Image(systemName: "rectangle.grid.3x2")
        }
    }
}
