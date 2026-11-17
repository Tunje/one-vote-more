"""Editorial compositions: varied subjects and framing, not reference-image layouts."""
SCENES = {
    "ECON_FAMINE": (
        "A wide view of a queue at a small bakery, empty bread shelves visible through the window.",
        "A tight still life inside a kitchen: an empty bread basket, an empty bowl and a single hand resting beside them. No window, street or crowd. Emphasise the empty space where a meal should be."),
    "POL_ELECTION_HELD": (
        "A public hall entrance with a modest line of people waiting to vote, ballot box visible inside.",
        "Close view of an ordinary voter's hand slipping one blank folded ballot into the slot of a plain wooden ballot box. Only hands and ballot box; background empty white."),
    "POL_GOVERNMENT_FORMED": (
        "A modest group of officials on the assembly steps, seen within the whole public-building setting.",
        "Interior still life of a cabinet table: several mismatched chairs gathered around it, plain folders and drinking glasses laid out for a new administration. No people, no exterior buildings."),
    "POL_NO_CONFIDENCE_PASSED": (
        "An assembly chamber viewed from its public gallery, members standing with blank papers raised.",
        "An abandoned ministerial desk with its chair pulled away and a half-packed plain briefcase lying open. One sleeve and hand gather a stack of blank folders. Tight interior composition, no chamber crowd."),
    "POL_NO_CONFIDENCE_FAILED": (
        "An assembly chamber with most members seated while one side applauds.",
        "Medium interior view of a relieved fictional minister seated alone on a plain bench after a difficult vote, hands unclasping, blank folders beside the person. Focus on posture, no spectators or chamber panorama."),
    "POL_SCANDAL_REVEALED": (
        "Reporters waiting outside an office, notebooks and cameras, no named subject or signs.",
        "A tipped-over desk inkwell spilling dark ink toward a bundle of blank official envelopes. The stark object arrangement suggests a stain on political trust. Close still life, no office facade, reporters or vehicles."),
    "POL_PARTNER_LEFT": (
        "A small group of suited officials walking away down the assembly steps.",
        "An indoor coat rack with an obvious empty hook between hanging formal jackets; beneath it an open briefcase held by a departing person's hand at the edge of the scene. Intimate composition about leaving, no public steps."),
    "POL_LEADER_CHANGED": (
        "A fictional party leader seen from behind at a lectern addressing a hall.",
        "Two fictional adults exchanging a plain office key over an uncluttered desk, focus on the hands and key rather than faces. A symbolic transfer of leadership; no lectern, crowd or exterior."),
    "POL_LEADERSHIP_RACE_OPENED": (
        "Two empty lecterns on a small meeting-hall stage, rows of seats waiting for a contest.",
        "Two fictional candidates sitting opposite each other at a small interview table, seen in profile at middle distance. Their different postures express a serious contest; no stage, audience, lecterns or logos."),
    "POL_PARTY_SPLIT": (
        "A disordered meeting hall with a loose torn blank banner and overturned chairs.",
        "A close symbolic object study: one blank cloth rosette torn into two pieces on a plain tabletop. Strong separation between the pieces. No room, crowd, street, flags or words."),
    "POL_BILL_DEFEATED": (
        "A clerk's desk in an assembly chamber, a hand applying a plain rubber stamp to blank papers.",
        "Overhead close view of a wastepaper basket with a thick bundle of rejected blank legislative pages, a plain broken pencil nearby. No people, chamber vista or readable marks."),
    "HOME_DEMAND_RAISED": (
        "A sealed official envelope on an administrator's desk, a small unlabelled globe nearby.",
        "A close view of an administrator's hand holding a heavy bundle of blank official demands, another bundle already weighing down the desk. Focus on burden and paperwork; no street beyond a window."),
    "HOME_SANCTION": (
        "A lonely warehouse on a dry spacecraft landing field, doors secured by an ordinary realistically sized chain and padlock, no vehicles or people. Medium view focused on the closed loading entrance; entirely inland, no water or boats.",
        "A close object study of an idle spaceport cargo trolley stopped behind a lowered barrier. Empty dry landing apron beyond, no ship, water, harbour or crowd. Visual emphasis on an interrupted connection."),
    "HOME_EXPEDITION_SENT": (
        "A utilitarian interplanetary spacecraft descending through a dark cloudy alien sky above distant low hills. Industrial cargo hull with landing legs and enclosed engines, not a sea vessel; broad sky composition, no water, sails, ship's funnel or nautical bow.",
        "A lone colony lookout at a bare hilltop observation post, seen in profile using binoculars toward a tiny industrial spacecraft silhouette in a cloud break. Focus on the lookout and uneasy sky, no town square or sea."),
    "HOME_PETITION_ANSWERED": (
        "An opened envelope, an indistinct letter and spectacles laid on a small desk.",
        "Close view of two work-worn hands carefully unfolding a blank official reply over a plain lap. Only hands, folded paper and a chair edge; no desk still life, globe or street background."),
    "HOME_SHIP_BUILT": (
        "A newly completed utilitarian cargo SPACECRAFT standing on stout landing legs in a dry industrial assembly yard, workers tiny beside its enormous cylindrical hull. Enclosed propulsion machinery and a broad cargo hatch; definitely no water, seagoing hull, funnel, mast or sails.",
        "An upward close view under the belly of a large industrial cargo spacecraft: a stout landing strut, riveted hull and engine nozzle, a worker inspecting the mechanism for scale. Dry concrete underfoot; no sea vessel, harbour, water or crowd."),
    "HOME_SHIPPING_REFUSED": (
        "A dry inland spacecraft landing field with many weathered cargo crates waiting under tarpaulins and no spacecraft present. Wide expanse of empty compacted ground beyond the cargo, low warehouse in distance, no water or boats.",
        "Inside a spaceport warehouse: close view of a freight handler's gloved hands securing a canvas cover over a shipment left waiting. The closed cargo door in the background opens onto dry ground, no harbour or vessels."),
    "LAW_CHARTER_AMENDED": (
        "An administrative notice being replaced in a frame outside a plain public building, writing indistinct.",
        "Close view of a hand carefully removing a seal from the corner of a blank charter sheet and placing a fresh seal beside it. Quiet tabletop composition, no public building, ladder or audience."),
    "LAW_CHARTER_DEFIANCE": (
        "A wide gathering of residents before a public building, raised fists and no party symbols.",
        "A single fictional assembly representative at a small desk pushing a sealed blank charter document away with a firm open hand. Medium interior view, restrained defiant posture, no rally or crowd."),
    "UNION_STRIKE_CALLED": (
        "A picket line outside a modest factory gate, all placards blank.",
        "A worker's hand carefully laying a plain spanner on an idle workbench beside unused gloves. Focus on the decision to withhold work, no picket line, signage, gate or exterior."),
    "UNION_STRIKE_COLLAPSED": (
        "A subdued group of workers dispersing at a factory entrance in early light.",
        "An abandoned picket's plain blank placard leaning against a low wall, a cold empty mug beside it, rain-speckled ground. No people or factory panorama. Close still life about a labour action ending."),
    "ECON_SOVEREIGN_DEFAULT": (
        "People waiting outside a closed financial office, its notice illegible.",
        "An accountant's hands beside an empty wooden cash drawer and a stack of blank unpaid vouchers. Close view of the empty drawer, no office exterior, bank queue or readable figures."),
    "ECON_SHIP_ARRIVED": (
        "A utilitarian interplanetary cargo SPACECRAFT settling onto broad landing feet on a dry inland landing pad, dust spreading beneath it. Low warehouses far away for scale. No sea, harbour, quay, boat hull, mast or sails.",
        "From inside a spacecraft cargo hatch: a ramp lowered onto the dry landing apron and the boots of an arriving settler at its top edge. Focus on threshold and first step; no water, seagoing ship, crowd or exterior spacecraft panorama."),
    "PLANET_CYCLONE": (
        "A wide plain residential street after a severe cyclone: a roof damaged, loose timber and people clearing debris. No injured people or bodies.",
        "Close view of two pairs of gloved hands lifting a storm-fallen wooden beam from a damaged doorway. A fragment of torn roof behind, no injured people, crowd or panorama. Emphasise repair and practical work."),
    "ECON_CONTRACT_SEVERELY_DELAYED": (
        "An unfinished low apartment block with silent scaffolding and no workers, wide grey open sky above.",
        "A close interior view at an unfinished doorway: a builder's untouched tools lie under a thick layer of dust beside an empty bucket. Strong sense of work that has stopped, no tower, street or people."),
    "COMP_LIQUIDATED": (
        "An empty industrial yard beyond chained factory gates, no readable sign, weeds at the threshold.",
        "An overhead still life of a plain company office key, an empty till and a folded blank business folder on a bare table. No people, building facade or readable writing; emphasis on an enterprise's end."),
    "ECON_LAYOFFS_MASS": (
        "Workers leaving an industrial workplace with small boxes of belongings, a restrained middle-distance composition without a crowd.",
        "An intimate study of a fictional worker's hands closing a plain cardboard box containing work gloves and a battered lunch tin. Only the box, hands and an emptied locker; no factory exit procession."),
    "COMP_WORKPLACE_ACCIDENT": (
        "A modest unmarked ambulance parked beside an industrial loading bay after an accident, a few workers standing aside. No patients, visible injuries, readable markings or logos.",
        "Close view of a halted machine with a snapped drive belt and a single abandoned protective glove nearby. No people or injury, no ambulance or crowd. A workplace-accident aftermath object study."),
    "POL_GRANT_FAVOURITISM": (
        "A new modest public building with a ribbon across its door beside an undeveloped bare plot, a clear contrast without ceremony or spectators.",
        "A fictional applicant seated alone at a kitchen table holding an indistinct refused application, face expressed through drawn posture rather than realistic detail. No buildings or comparative street vista; focus on the person passed over."),
    "POL_DEBATE_GAFFE": (
        "A fictional speaker at a debate lectern hesitating over blank notes, an opposing lectern visible at the far side of the stage; restrained medium view.",
        "A tight study of a speaker's hands fumbling blank note cards beside a plain tabletop microphone. Cards slide out of order. No face, stage panorama, second speaker or audience."),
    "FEATURE_DISTRICT_PORTRAIT": (
        "A quiet residential lane with modest low homes and washing on a line, no bus, excavation or crowd.",
        "A domestic doorway at close range: worn boots, a repaired stool and a plant pot, with a neighbour's hand resting on the doorframe. A small lived-in detail of a district, no street panorama."),
    "FEATURE_LETTERS": (
        "Overhead still life of assorted folded letters on an editor's small desk, a plain pen and ink bottle, all writing indistinct. No window or town background.",
        "A fictional reader at a kitchen table composing a letter, viewed at middle distance in a quiet plain room. No piles of letters, editorial office, street or legible marks."),
    "FEATURE_SHIP_DAY": (
        "A wide empty inland spacecraft landing field at dawn, a low warehouse and distant hills, faint two moons above. No water, piers, boats or sea horizon.",
        "A solitary spaceport worker inside a small control hut looking through a square window onto a dry landing pad. Simple analog instruments have no readable markings. Quiet waiting, no sea, ships on water or crowd."),
    "FEATURE_SEASON": (
        "A large alien sky with two faint moons above broad cultivated fields and distant low hills; no buildings, vehicles or crowd.",
        "A close botanical study of wind-bent grain heads and a farmer's hand testing a handful of soil. Open paper around the subject, no sky panorama, town or named crop label."),
    "FEATURE_FOUNDERS": (
        "A handful of first-generation prefabricated colony shelters in a bare landscape, a few settlers unloading plain crates, no flags or celebratory stage.",
        "A battered original settler's travel trunk beneath a simple bunk, its contents a folded work jacket, a plain bowl and a hand tool. Intimate still life of the colony's beginnings, no people or settlement panorama."),
    "FEATURE_MARKET": (
        "An interior covered market aisle with ordinary bread and vegetable stalls, a few shoppers, no signs or readable prices.",
        "Close view of a market seller's hands weighing vegetables in a plain balance scale while a buyer holds an open cloth bag. No crowd, signs, price figures or full market panorama."),
    "FEATURE_ASSEMBLY_SKETCH": (
        "A quiet almost-empty assembly room, one fictional member asleep far back on a bench, unremarkable everyday public business.",
        "A drowsy fictional assembly member's hand letting a pencil droop above a blank notebook, a cold cup beside it. Close desk detail, no chamber panorama or crowd."),
    "FEATURE_WORK": (
        "A baker at a modest oven before dawn, interior medium composition with kneading bench and no customers.",
        "A nurse's hands carefully folding clean dressings at a small treatment-room worktop. No patient, blood, lettering or other person; focus on an ordinary useful task distinct from baking."),
    "GENERIC_ASSEMBLY": (
        "Architectural view of a plain colonial assembly building and wide empty steps, no crowd, bus or unrelated machinery.",
        "An assembly clerk's small indoor workstation: a plain bell, stacked blank folders and an empty chair. Close interior still life, no exterior architecture."),
    "GENERIC_PORT": (
        "A dry inland SPACEPORT: an ordinary loading vehicle approaching a landed utilitarian cargo spacecraft on broad feet, low warehouses beyond. No water, boat hull, harbour, seagoing ship or nautical structures.",
        "Close view of an industrial spacecraft loading hatch connected to a small wheeled cargo conveyor on a dry concrete apron. The closed engine housing is overhead. No sea, boats, crowd or panoramic port scene."),
    "GENERIC_STREET": (
        "A small-town main street with a bus at a plain shelter, ordinary low buildings and a few pedestrians; no construction site.",
        "View from inside an empty simple bus looking through the driver's area toward a quiet intersection. Unlabelled analog controls, no readable routes, signs or crowd."),
    "GENERIC_FACTORY": (
        "A modest colonial factory from across its quiet loading yard, simple chimney and one delivery truck, no people gathered at the gate.",
        "An interior workshop study of a lathe, scattered metal shavings and a worker's hands adjusting its stopped chuck. No exterior factory, trucks, crowd or signs."),
    "GENERIC_FARM": (
        "A small farmhouse and barns among worked fields, a single utilitarian tractor, an open rural composition with no crowd.",
        "A farmer's muddy boots and a plain hand tool at the edge of freshly worked soil, low close composition. No farmhouse, tractor panorama or other person."),
    "ECON_PANDEMIC": (
        "A fictional sick adult sitting at home beside an untouched work jacket, another adult offering a plain cup of water. Restrained domestic scene, no gore or clinical labels, no queue outside a building.",
        "An empty workshop floor with idle machines and a row of unused work coats on hooks. No people, readable labels, exterior factory or clinic queue."),
}
