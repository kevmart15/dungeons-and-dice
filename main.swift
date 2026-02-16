import AppKit
import SceneKit
import SpriteKit
import Foundation

// MARK: - Dice Utilities
func rollD(_ n: Int) -> Int { Int.random(in: 1...n) }
func rollDice(count: Int, sides: Int) -> (rolls: [Int], total: Int) {
    var rolls: [Int] = []; var total = 0
    for _ in 0..<count { let r = rollD(sides); rolls.append(r); total += r }
    return (rolls, total)
}
func abilityMod(_ score: Int) -> Int { (score - 10) / 2 }

// MARK: - Enums
enum CharacterClass: String, CaseIterable {
    case fighter = "FIGHTER", rogue = "ROGUE", cleric = "CLERIC", wizard = "WIZARD", warlock = "WARLOCK"
}
enum GameState {
    case mainMenu, village, worldMap, dungeon, combat, dialogue, questBoard, shop, rest, inventory, traveling, gameOver
}
enum QuestType { case kill, retrieve, explore, escort }
enum ItemType { case potion, antidote, ration, weaponUpgrade, armorUpgrade, speedPotion, strengthPotion }
enum StatusEffect: String { case poisoned = "POISONED", stunned = "STUNNED", slowed = "SLOWED", blessed = "BLESSED", shielded = "SHIELDED" }

enum MonsterType: String {
    case giantRat = "Giant Rat", goblin = "Goblin", skeletonWarrior = "Skeleton Warrior"
    case skeletonArcher = "Skeleton Archer", orcBerserker = "Orc Berserker", giantSpider = "Giant Spider"
    case darkMage = "Dark Mage", troll = "Troll", mimic = "Mimic", wraith = "Wraith"
    case ogre = "Ogre", youngDragon = "Young Dragon"
}

enum LocationID: String, CaseIterable {
    case oakvale = "Oakvale", silverwood = "Silverwood", ironhold = "Ironhold"
    case marshfen = "Marshfen", theWilds = "The Wilds"
}

enum BuildingType: String {
    case inn, guild, generalShop, blacksmith, druidCircle, archeryTrainer
    case herbalist, masterForge, mineEntrance, aleHall, herbShop, fishingDock
    case swampEntrance, goblinCaves, undeadCrypt, dragonLair
}

enum GuildRank: String {
    case copper = "Copper", silver = "Silver", gold = "Gold", platinum = "Platinum"
}

// MARK: - Data Structures
struct AbilityScores {
    var str: Int = 10; var dex: Int = 10; var con: Int = 10
    var intel: Int = 10; var wis: Int = 10; var cha: Int = 10
    static func generate(forClass cls: CharacterClass) -> AbilityScores {
        var s = AbilityScores()
        let roll = { () -> Int in
            var r = (0..<4).map { _ in rollD(6) }; r.sort(); return r[1]+r[2]+r[3]
        }
        var rolls = (0..<6).map { _ in roll() }; rolls.sort(by: >)
        switch cls {
        case .fighter:  s.str=rolls[0]; s.con=rolls[1]; s.dex=rolls[2]; s.wis=rolls[3]; s.intel=rolls[4]; s.cha=rolls[5]
        case .rogue:    s.dex=rolls[0]; s.con=rolls[1]; s.str=rolls[2]; s.cha=rolls[3]; s.wis=rolls[4]; s.intel=rolls[5]
        case .cleric:   s.wis=rolls[0]; s.con=rolls[1]; s.str=rolls[2]; s.cha=rolls[3]; s.intel=rolls[4]; s.dex=rolls[5]
        case .wizard:   s.intel=rolls[0]; s.dex=rolls[1]; s.con=rolls[2]; s.wis=rolls[3]; s.cha=rolls[4]; s.str=rolls[5]
        case .warlock:  s.cha=rolls[0]; s.con=rolls[1]; s.dex=rolls[2]; s.intel=rolls[3]; s.wis=rolls[4]; s.str=rolls[5]
        }
        return s
    }
}

struct Item {
    let name: String; let type: ItemType; let value: Int; let cost: Int
    var description: String { return "\(name) (val:\(value), \(cost)g)" }
}

struct Quest {
    let id: String; let name: String; let description: String; let type: QuestType
    let targetCount: Int; var progress: Int; let rewardXP: Int; let rewardGold: Int
    let requiredFloor: Int; var completed: Bool
    var targetMonster: MonsterType?
    var targetDungeon: String?
}

struct DialogueOption {
    let label: String; let action: String
}
struct DialogueLine {
    let text: String; let responses: [DialogueOption]
}
struct NPCData {
    let name: String; let race: String; let location: LocationID
    let dialogues: [DialogueLine]; let patrolPath: [(Int,Int)]
}

struct BuildingData {
    let name: String; let type: BuildingType; let gridX: Int; let gridZ: Int; let width: Int; let depth: Int
}

struct LocationData {
    let id: LocationID; let name: String; let description: String
    let buildings: [BuildingData]; let npcs: [NPCData]
    let connections: [LocationID]
    let mapX: CGFloat; let mapY: CGFloat
}

struct ActiveEffect {
    let effect: StatusEffect; var turnsRemaining: Int; let value: Int
}

// MARK: - Monster Template
struct MonsterTemplate {
    let type: MonsterType; let ac: Int; let maxHP: Int; let attackDice: Int; let attackSides: Int
    let attackBonus: Int; let xpReward: Int; let isRanged: Bool; let range: Int
    let specialAbility: String; let cr: Double
}

let monsterTemplates: [MonsterType: MonsterTemplate] = [
    .giantRat: MonsterTemplate(type:.giantRat, ac:12, maxHP:7, attackDice:1, attackSides:4, attackBonus:2, xpReward:25, isRanged:false, range:1, specialAbility:"", cr:0.25),
    .goblin: MonsterTemplate(type:.goblin, ac:15, maxHP:7, attackDice:1, attackSides:6, attackBonus:2, xpReward:25, isRanged:false, range:1, specialAbility:"", cr:0.25),
    .skeletonWarrior: MonsterTemplate(type:.skeletonWarrior, ac:13, maxHP:13, attackDice:1, attackSides:6, attackBonus:2, xpReward:50, isRanged:false, range:1, specialAbility:"", cr:0.5),
    .skeletonArcher: MonsterTemplate(type:.skeletonArcher, ac:13, maxHP:11, attackDice:1, attackSides:6, attackBonus:2, xpReward:50, isRanged:true, range:5, specialAbility:"", cr:0.5),
    .orcBerserker: MonsterTemplate(type:.orcBerserker, ac:13, maxHP:20, attackDice:1, attackSides:12, attackBonus:3, xpReward:100, isRanged:false, range:1, specialAbility:"rage", cr:1),
    .giantSpider: MonsterTemplate(type:.giantSpider, ac:14, maxHP:15, attackDice:1, attackSides:8, attackBonus:2, xpReward:100, isRanged:false, range:1, specialAbility:"web_poison", cr:1),
    .darkMage: MonsterTemplate(type:.darkMage, ac:12, maxHP:18, attackDice:1, attackSides:8, attackBonus:3, xpReward:200, isRanged:true, range:5, specialAbility:"shield", cr:2),
    .troll: MonsterTemplate(type:.troll, ac:12, maxHP:40, attackDice:1, attackSides:10, attackBonus:4, xpReward:200, isRanged:false, range:1, specialAbility:"regenerate", cr:2),
    .mimic: MonsterTemplate(type:.mimic, ac:12, maxHP:30, attackDice:2, attackSides:6, attackBonus:3, xpReward:200, isRanged:false, range:1, specialAbility:"surprise", cr:2),
    .wraith: MonsterTemplate(type:.wraith, ac:13, maxHP:25, attackDice:1, attackSides:8, attackBonus:3, xpReward:350, isRanged:false, range:1, specialAbility:"life_drain", cr:3),
    .ogre: MonsterTemplate(type:.ogre, ac:11, maxHP:59, attackDice:2, attackSides:8, attackBonus:4, xpReward:350, isRanged:false, range:1, specialAbility:"ground_slam", cr:3),
    .youngDragon: MonsterTemplate(type:.youngDragon, ac:18, maxHP:85, attackDice:1, attackSides:10, attackBonus:4, xpReward:900, isRanged:false, range:1, specialAbility:"breath_weapon", cr:5),
]

// MARK: - Quest Pool
let questPool: [Quest] = [
    Quest(id:"q1",name:"Rat Extermination",description:"Kill 5 Giant Rats in Goblin Caves",type:.kill,targetCount:5,progress:0,rewardXP:50,rewardGold:20,requiredFloor:0,completed:false,targetMonster:.giantRat,targetDungeon:"Goblin Caves"),
    Quest(id:"q2",name:"Goblin Menace",description:"Kill 8 Goblins",type:.kill,targetCount:8,progress:0,rewardXP:100,rewardGold:40,requiredFloor:0,completed:false,targetMonster:.goblin,targetDungeon:nil),
    Quest(id:"q3",name:"The Lost Amulet",description:"Reach floor 3 of Undead Crypt",type:.explore,targetCount:3,progress:0,rewardXP:150,rewardGold:60,requiredFloor:3,completed:false,targetMonster:nil,targetDungeon:"Undead Crypt"),
    Quest(id:"q4",name:"Orc Warband",description:"Kill 3 Orcs",type:.kill,targetCount:3,progress:0,rewardXP:120,rewardGold:50,requiredFloor:0,completed:false,targetMonster:.orcBerserker,targetDungeon:nil),
    Quest(id:"q5",name:"Spider Silk",description:"Kill 5 Giant Spiders",type:.kill,targetCount:5,progress:0,rewardXP:80,rewardGold:35,requiredFloor:0,completed:false,targetMonster:.giantSpider,targetDungeon:nil),
    Quest(id:"q6",name:"Clear the Mine",description:"Reach floor 3 of Ironhold Mine",type:.explore,targetCount:3,progress:0,rewardXP:200,rewardGold:80,requiredFloor:3,completed:false,targetMonster:nil,targetDungeon:"Ironhold Mine"),
    Quest(id:"q7",name:"Dragon Sighting",description:"Reach floor 1 of Dragon's Lair",type:.explore,targetCount:1,progress:0,rewardXP:300,rewardGold:120,requiredFloor:1,completed:false,targetMonster:nil,targetDungeon:"Dragon's Lair"),
    Quest(id:"q8",name:"Undead Rising",description:"Kill 10 Skeletons",type:.kill,targetCount:10,progress:0,rewardXP:130,rewardGold:55,requiredFloor:0,completed:false,targetMonster:.skeletonWarrior,targetDungeon:nil),
    Quest(id:"q9",name:"Troll Bridge",description:"Kill 2 Trolls",type:.kill,targetCount:2,progress:0,rewardXP:250,rewardGold:100,requiredFloor:0,completed:false,targetMonster:.troll,targetDungeon:nil),
    Quest(id:"q10",name:"The Dark Mage",description:"Kill 3 Dark Mages",type:.kill,targetCount:3,progress:0,rewardXP:180,rewardGold:70,requiredFloor:0,completed:false,targetMonster:.darkMage,targetDungeon:nil),
]

// MARK: - Shop Inventories
let generalShopItems: [Item] = [
    Item(name:"Healing Potion",type:.potion,value:0,cost:25),
    Item(name:"Antidote",type:.antidote,value:0,cost:15),
    Item(name:"Rations",type:.ration,value:0,cost:10),
]
let herbalistItems: [Item] = [
    Item(name:"Potion of Speed",type:.speedPotion,value:2,cost:40),
    Item(name:"Potion of Strength",type:.strengthPotion,value:2,cost:40),
]

// MARK: - Campaign Chapters
struct CampaignChapter {
    let number: Int; let title: String; let intro: String; let objective: String
}
let campaignChapters: [CampaignChapter] = [
    CampaignChapter(number:1,title:"The Beginning",intro:"You arrive in Oakvale, a small human settlement nestled between rolling green hills. Smoke rises from the tavern chimney. The Mayor seeks adventurers...",objective:"Talk to Mayor Aldric. Clear Goblin Caves floor 3."),
    CampaignChapter(number:2,title:"The Forest's Plight",intro:"The ancient trees of Silverwood tower above you. Elven lanterns glow softly among the branches. But darkness stirs within...",objective:"Travel to Silverwood. Help Elder Aelindra investigate the forest corruption."),
    CampaignChapter(number:3,title:"Heart of the Mountain",intro:"The great gates of Ironhold stand before you, carved with dwarven runes of power. The forges have gone cold...",objective:"Journey to Ironhold. Aid Forgemaster Durin. Clear the Mine."),
    CampaignChapter(number:4,title:"Swamp of Shadows",intro:"A fetid mist hangs over Marshfen. The halfling folk speak in whispers of dark things rising from the deep...",objective:"Visit Marshfen. Discover the source of evil. Enter the Crypt."),
    CampaignChapter(number:5,title:"Dragon's End",intro:"The path leads ever upward into the Wilds. Charred trees and scorched earth mark the dragon's domain...",objective:"Assault Dragon's Lair. Defeat the Young Dragon."),
]

// MARK: - NPC Dialogue Data
func buildNPCData() -> [NPCData] {
    return [
        // Oakvale NPCs
        NPCData(name:"Mayor Aldric",race:"Human",location:.oakvale,dialogues:[
            DialogueLine(text:"Welcome to Oakvale, adventurer! Our village is beset by monsters from the nearby caves. We need someone brave to help.",responses:[
                DialogueOption(label:"I'll help. What do you need?",action:"quest_campaign1"),
                DialogueOption(label:"Tell me about Oakvale.",action:"info_oakvale"),
                DialogueOption(label:"Farewell.",action:"close"),
            ]),
        ],patrolPath:[(8,8),(8,10),(10,10),(10,8)]),
        NPCData(name:"Barmaid Sera",race:"Human",location:.oakvale,dialogues:[
            DialogueLine(text:"Care for a drink? I hear rumors from all sorts who pass through here.",responses:[
                DialogueOption(label:"What rumors have you heard?",action:"info_rumor"),
                DialogueOption(label:"No thanks.",action:"close"),
            ]),
        ],patrolPath:[(4,4),(6,4),(6,6),(4,6)]),
        NPCData(name:"Guildmaster Theron",race:"Human",location:.oakvale,dialogues:[
            DialogueLine(text:"The Adventurers Guild welcomes all who seek glory and coin. Check the quest board for available work.",responses:[
                DialogueOption(label:"Show me the quest board.",action:"quest_board"),
                DialogueOption(label:"What's my guild rank?",action:"info_rank"),
                DialogueOption(label:"Goodbye.",action:"close"),
            ]),
        ],patrolPath:[(12,4),(12,6)]),
        NPCData(name:"Merchant Pip",race:"Halfling",location:.oakvale,dialogues:[
            DialogueLine(text:"Pip's General Goods! Best prices in Oakvale! Well... only prices in Oakvale!",responses:[
                DialogueOption(label:"Show me your wares.",action:"shop_general"),
                DialogueOption(label:"Maybe later.",action:"close"),
            ]),
        ],patrolPath:[(3,12),(5,12)]),
        // Silverwood NPCs
        NPCData(name:"Elder Aelindra",race:"Elf",location:.silverwood,dialogues:[
            DialogueLine(text:"The forest speaks of a growing darkness. Ancient evils stir beneath the roots of Silverwood.",responses:[
                DialogueOption(label:"How can I help?",action:"quest_campaign2"),
                DialogueOption(label:"Tell me of the elves.",action:"info_silverwood"),
                DialogueOption(label:"I must go.",action:"close"),
            ]),
        ],patrolPath:[(8,8),(10,8),(10,10)]),
        NPCData(name:"Ranger Faelan",race:"Elf",location:.silverwood,dialogues:[
            DialogueLine(text:"The woods are dangerous. Strange creatures roam where once only deer walked.",responses:[
                DialogueOption(label:"Any work for a ranger?",action:"info_rumor"),
                DialogueOption(label:"Stay safe.",action:"close"),
            ]),
        ],patrolPath:[(4,10),(6,10),(6,12)]),
        NPCData(name:"Herbalist Yara",race:"Elf",location:.silverwood,dialogues:[
            DialogueLine(text:"My potions are brewed from the rarest herbs of Silverwood. They will aid you well.",responses:[
                DialogueOption(label:"Show me your potions.",action:"shop_herbalist"),
                DialogueOption(label:"Not now, thank you.",action:"close"),
            ]),
        ],patrolPath:[(12,6),(12,8)]),
        // Ironhold NPCs
        NPCData(name:"Forgemaster Durin",race:"Dwarf",location:.ironhold,dialogues:[
            DialogueLine(text:"My forge has crafted the finest weapons in the realm! But the mine... the mine has been overrun.",responses:[
                DialogueOption(label:"I can clear the mine.",action:"quest_campaign3"),
                DialogueOption(label:"Can you upgrade my gear?",action:"shop_blacksmith"),
                DialogueOption(label:"Good day.",action:"close"),
            ]),
        ],patrolPath:[(8,6),(10,6),(10,8)]),
        NPCData(name:"Miner Brok",race:"Dwarf",location:.ironhold,dialogues:[
            DialogueLine(text:"The mine's crawling with orcs and spiders. We barely escaped with our lives!",responses:[
                DialogueOption(label:"I'll deal with them.",action:"info_mine"),
                DialogueOption(label:"Sounds dangerous.",action:"close"),
            ]),
        ],patrolPath:[(4,8),(6,8),(6,10)]),
        NPCData(name:"Brewmaster Olga",race:"Dwarf",location:.ironhold,dialogues:[
            DialogueLine(text:"A fine dwarven ale before battle? It'll put fire in your belly!",responses:[
                DialogueOption(label:"I'll have an ale! (5 gold)",action:"buff_ale"),
                DialogueOption(label:"Maybe after the fight.",action:"close"),
            ]),
        ],patrolPath:[(12,10),(12,12)]),
        // Marshfen NPCs
        NPCData(name:"Fisher Tilly",race:"Halfling",location:.marshfen,dialogues:[
            DialogueLine(text:"The fish ain't biting like they used to. Something foul in the water, I reckon.",responses:[
                DialogueOption(label:"I'll investigate.",action:"info_rumor"),
                DialogueOption(label:"Good luck fishing.",action:"close"),
            ]),
        ],patrolPath:[(4,4),(6,4),(6,6)]),
        NPCData(name:"Witch Morga",race:"Halfling",location:.marshfen,dialogues:[
            DialogueLine(text:"Heh heh... seeking power, are we? Morga can help... for a price.",responses:[
                DialogueOption(label:"What do you offer?",action:"quest_campaign4"),
                DialogueOption(label:"No thanks, witch.",action:"close"),
            ]),
        ],patrolPath:[(10,10),(12,10),(12,12)]),
        NPCData(name:"Scout Nim",race:"Halfling",location:.marshfen,dialogues:[
            DialogueLine(text:"I know every path through the swamp. The crypt entrance is to the south, but beware the spiders.",responses:[
                DialogueOption(label:"Guide me to the crypt.",action:"info_swamp"),
                DialogueOption(label:"Thanks for the tip.",action:"close"),
            ]),
        ],patrolPath:[(8,6),(8,8),(10,8)]),
    ]
}

// MARK: - Location Data
func buildLocationData() -> [LocationID: LocationData] {
    return [
        .oakvale: LocationData(id:.oakvale,name:"Oakvale",description:"A small human settlement nestled between rolling green hills.",
            buildings:[
                BuildingData(name:"Inn",type:.inn,gridX:3,gridZ:3,width:3,depth:3),
                BuildingData(name:"Adventurers Guild",type:.guild,gridX:10,gridZ:3,width:4,depth:3),
                BuildingData(name:"General Shop",type:.generalShop,gridX:3,gridZ:10,width:3,depth:2),
                BuildingData(name:"Blacksmith",type:.blacksmith,gridX:10,gridZ:10,width:3,depth:2),
            ],npcs:buildNPCData().filter{$0.location == .oakvale},
            connections:[.silverwood,.ironhold,.theWilds],mapX:200,mapY:360),
        .silverwood: LocationData(id:.silverwood,name:"Silverwood",description:"Ancient elven forest where lanterns glow among towering trees.",
            buildings:[
                BuildingData(name:"Druid Circle",type:.druidCircle,gridX:7,gridZ:4,width:4,depth:4),
                BuildingData(name:"Archery Trainer",type:.archeryTrainer,gridX:3,gridZ:10,width:3,depth:2),
                BuildingData(name:"Herbalist",type:.herbalist,gridX:11,gridZ:10,width:3,depth:2),
            ],npcs:buildNPCData().filter{$0.location == .silverwood},
            connections:[.oakvale,.marshfen],mapX:400,mapY:550),
        .ironhold: LocationData(id:.ironhold,name:"Ironhold",description:"A mighty dwarven stronghold carved into the mountain itself.",
            buildings:[
                BuildingData(name:"Master Forge",type:.masterForge,gridX:7,gridZ:3,width:4,depth:3),
                BuildingData(name:"Mine Entrance",type:.mineEntrance,gridX:3,gridZ:10,width:3,depth:2),
                BuildingData(name:"Ale Hall",type:.aleHall,gridX:11,gridZ:10,width:3,depth:2),
            ],npcs:buildNPCData().filter{$0.location == .ironhold},
            connections:[.oakvale,.theWilds],mapX:400,mapY:170),
        .marshfen: LocationData(id:.marshfen,name:"Marshfen",description:"A fetid hamlet at the edge of the great swamp. Mist hangs heavy.",
            buildings:[
                BuildingData(name:"Herb Shop",type:.herbShop,gridX:3,gridZ:4,width:3,depth:2),
                BuildingData(name:"Fishing Dock",type:.fishingDock,gridX:10,gridZ:4,width:3,depth:2),
                BuildingData(name:"Swamp Entrance",type:.swampEntrance,gridX:7,gridZ:12,width:3,depth:2),
            ],npcs:buildNPCData().filter{$0.location == .marshfen},
            connections:[.silverwood,.theWilds],mapX:700,mapY:500),
        .theWilds: LocationData(id:.theWilds,name:"The Wilds",description:"Untamed wilderness. Dungeon entrances dot the landscape.",
            buildings:[
                BuildingData(name:"Goblin Caves",type:.goblinCaves,gridX:3,gridZ:4,width:3,depth:2),
                BuildingData(name:"Undead Crypt",type:.undeadCrypt,gridX:10,gridZ:4,width:3,depth:2),
                BuildingData(name:"Dragon's Lair",type:.dragonLair,gridX:7,gridZ:12,width:3,depth:2),
            ],npcs:[],
            connections:[.oakvale,.ironhold,.marshfen],mapX:700,mapY:250),
    ]
}

// MARK: - Dungeon Data
struct DungeonInfo {
    let name: String; let floors: Int; let enemyTypes: [MonsterType]; let bossType: MonsterType?
}
let dungeonData: [String: DungeonInfo] = [
    "Goblin Caves": DungeonInfo(name:"Goblin Caves",floors:3,enemyTypes:[.giantRat,.goblin],bossType:nil),
    "Undead Crypt": DungeonInfo(name:"Undead Crypt",floors:4,enemyTypes:[.skeletonWarrior,.skeletonArcher,.wraith],bossType:nil),
    "Ironhold Mine": DungeonInfo(name:"Ironhold Mine",floors:3,enemyTypes:[.orcBerserker,.ogre,.giantSpider],bossType:nil),
    "Swamp Dungeon": DungeonInfo(name:"Swamp Dungeon",floors:3,enemyTypes:[.giantSpider,.darkMage,.troll],bossType:nil),
    "Dragon's Lair": DungeonInfo(name:"Dragon's Lair",floors:5,enemyTypes:[.troll,.darkMage],bossType:.youngDragon),
]

// MARK: - Player Character
class PlayerCharacter {
    var name: String = "Hero"
    var cls: CharacterClass = .fighter
    var level: Int = 1; var xp: Int = 0; var xpToNext: Int = 100
    var abilities: AbilityScores = AbilityScores()
    var maxHP: Int = 10; var hp: Int = 10; var ac: Int = 10
    var gold: Int = 50; var day: Int = 1
    var gridX: Int = 8; var gridZ: Int = 8
    var speed: Int = 6; var movementLeft: Int = 6
    var inventory: [Item] = []
    var activeQuests: [Quest] = []; var completedQuests: [Quest] = []
    var guildRank: GuildRank = .copper; var questsCompleted: Int = 0
    var campaignChapter: Int = 1
    var weaponBonus: Int = 0; var armorBonus: Int = 0
    var mana: Int = 0; var maxMana: Int = 0
    var pactPoints: Int = 0; var maxPactPoints: Int = 5
    var effects: [ActiveEffect] = []
    var abilityUses: [Int: Int] = [2:0,3:0,4:0]
    var node: SCNNode?
    var comboCount: Int = 0
    var familiarNode: SCNNode?; var familiarHP: Int = 0; var familiarTurns: Int = 0
    var familiarGridX: Int = 0; var familiarGridZ: Int = 0

    func initialize(cls: CharacterClass) {
        self.cls = cls
        abilities = AbilityScores.generate(forClass: cls)
        switch cls {
        case .fighter:
            maxHP = rollD(10) + abilityMod(abilities.con) + 10; ac = 17
            speed = 6
        case .rogue:
            maxHP = rollD(8) + abilityMod(abilities.con) + 8; ac = 15
            speed = 7
        case .cleric:
            maxHP = rollD(8) + abilityMod(abilities.con) + 8; ac = 16
            speed = 5
        case .wizard:
            maxHP = rollD(6) + abilityMod(abilities.con) + 6; ac = 12
            speed = 5; maxMana = 10 + abilityMod(abilities.intel); mana = maxMana
        case .warlock:
            maxHP = rollD(8) + abilityMod(abilities.con) + 8; ac = 13
            speed = 6; pactPoints = 0
        }
        hp = maxHP
        movementLeft = speed
        resetAbilityUses()
    }

    func resetAbilityUses() {
        switch cls {
        case .fighter: abilityUses[2] = 2; abilityUses[3] = 1; abilityUses[4] = 1
        case .rogue:   abilityUses[2] = 2; abilityUses[3] = 2; abilityUses[4] = 2
        case .cleric:  abilityUses[2] = 3; abilityUses[3] = 2; abilityUses[4] = 1
        case .wizard:  abilityUses[2] = 99; abilityUses[3] = 99; abilityUses[4] = 99
        case .warlock: abilityUses[2] = 2; abilityUses[3] = 99; abilityUses[4] = 99
        }
    }

    func primaryMod() -> Int {
        switch cls {
        case .fighter: return abilityMod(abilities.str)
        case .rogue: return abilityMod(abilities.dex)
        case .cleric: return abilityMod(abilities.wis)
        case .wizard: return abilityMod(abilities.intel)
        case .warlock: return abilityMod(abilities.cha)
        }
    }

    var effectiveAC: Int {
        var a = ac + armorBonus
        for e in effects where e.effect == .shielded { a += e.value }
        return a
    }

    func xpForLevel(_ l: Int) -> Int { return l * 100 }

    func gainXP(_ amount: Int) -> Bool {
        xp += amount
        if xp >= xpToNext {
            level += 1; xp -= xpToNext; xpToNext = xpForLevel(level + 1)
            let hpGain: Int
            switch cls {
            case .fighter: hpGain = rollD(10) + abilityMod(abilities.con)
            case .rogue, .cleric, .warlock: hpGain = rollD(8) + abilityMod(abilities.con)
            case .wizard: hpGain = rollD(6) + abilityMod(abilities.con)
            }
            maxHP += max(1, hpGain); hp = maxHP
            if cls == .wizard { maxMana += 2; mana = maxMana }
            resetAbilityUses()
            return true
        }
        return false
    }
}

// MARK: - Monster Character
class MonsterCharacter {
    var type: MonsterType; var ac: Int; var maxHP: Int; var hp: Int
    var attackDice: Int; var attackSides: Int; var attackBonus: Int
    var xpReward: Int; var isRanged: Bool; var range: Int
    var specialAbility: String; var cr: Double
    var gridX: Int; var gridZ: Int
    var node: SCNNode?; var effects: [ActiveEffect] = []
    var hasActed: Bool = false; var revealed: Bool = true
    var breathRecharge: Bool = false; var usedGroundSlam: Bool = false
    var shieldActive: Bool = false

    init(type: MonsterType, gridX: Int, gridZ: Int) {
        let t = monsterTemplates[type]!
        self.type = type; self.ac = t.ac; self.maxHP = t.maxHP; self.hp = t.maxHP
        self.attackDice = t.attackDice; self.attackSides = t.attackSides; self.attackBonus = t.attackBonus
        self.xpReward = t.xpReward; self.isRanged = t.isRanged; self.range = t.range
        self.specialAbility = t.specialAbility; self.cr = t.cr
        self.gridX = gridX; self.gridZ = gridZ
        if type == .mimic { revealed = false }
    }

    var effectiveAC: Int {
        var a = ac
        if shieldActive { a += 2 }
        return a
    }
}

// MARK: - Dungeon Generator
class DungeonGenerator {
    struct Room { var x: Int; var y: Int; var w: Int; var h: Int }
    var width: Int; var height: Int
    var grid: [[Int]] // 0=wall, 1=floor, 2=door, 3=stairs_down, 4=chest, 5=trap
    var rooms: [Room] = []
    var playerStart: (Int,Int) = (1,1)
    var stairsPos: (Int,Int) = (1,1)

    init(width: Int = 24, height: Int = 24) {
        self.width = width; self.height = height
        grid = Array(repeating: Array(repeating: 0, count: width), count: height)
    }

    func generate(floor: Int) {
        grid = Array(repeating: Array(repeating: 0, count: width), count: height)
        rooms = []
        let roomCount = 5 + floor
        for _ in 0..<roomCount * 3 {
            if rooms.count >= roomCount { break }
            let w = Int.random(in: 3...6); let h = Int.random(in: 3...6)
            let x = Int.random(in: 1...(width - w - 1)); let y = Int.random(in: 1...(height - h - 1))
            let newRoom = Room(x: x, y: y, w: w, h: h)
            var overlaps = false
            for r in rooms {
                if newRoom.x-1 < r.x+r.w && newRoom.x+newRoom.w+1 > r.x && newRoom.y-1 < r.y+r.h && newRoom.y+newRoom.h+1 > r.y {
                    overlaps = true; break
                }
            }
            if !overlaps {
                for dy in 0..<h { for dx in 0..<w { grid[y+dy][x+dx] = 1 } }
                rooms.append(newRoom)
            }
        }
        for i in 1..<rooms.count { connectRooms(rooms[i-1], rooms[i]) }
        if let first = rooms.first { playerStart = (first.x + first.w/2, first.y + first.h/2) }
        if let last = rooms.last { stairsPos = (last.x + last.w/2, last.y + last.h/2); grid[stairsPos.1][stairsPos.0] = 3 }
        // Place chests and traps
        for i in 1..<rooms.count {
            let r = rooms[i]
            if Int.random(in: 0..<3) == 0 {
                let cx = r.x + Int.random(in: 0..<r.w); let cy = r.y + Int.random(in: 0..<r.h)
                if grid[cy][cx] == 1 { grid[cy][cx] = 4 }
            }
            if Int.random(in: 0..<4) == 0 && floor > 1 {
                let tx = r.x + Int.random(in: 0..<r.w); let ty = r.y + Int.random(in: 0..<r.h)
                if grid[ty][tx] == 1 { grid[ty][tx] = 5 }
            }
        }
    }

    private func connectRooms(_ a: Room, _ b: Room) {
        var cx = a.x + a.w/2; var cy = a.y + a.h/2
        let tx = b.x + b.w/2; let ty = b.y + b.h/2
        while cx != tx { cx += cx < tx ? 1 : -1; if grid[cy][cx] == 0 { grid[cy][cx] = 1 } }
        while cy != ty { cy += cy < ty ? 1 : -1; if grid[cy][cx] == 0 { grid[cy][cx] = 1 } }
    }

    func spawnMonsters(types: [MonsterType], floor: Int) -> [MonsterCharacter] {
        var monsters: [MonsterCharacter] = []
        let count = 3 + floor * 2
        for i in 1..<rooms.count {
            if monsters.count >= count { break }
            let r = rooms[i]
            let num = min(2 + floor/2, count - monsters.count)
            for _ in 0..<num {
                let mx = r.x + Int.random(in: 0..<r.w); let my = r.y + Int.random(in: 0..<r.h)
                if grid[my][mx] == 1 {
                    let t = types[Int.random(in: 0..<types.count)]
                    monsters.append(MonsterCharacter(type: t, gridX: mx, gridZ: my))
                }
            }
        }
        return monsters
    }
}

// MARK: - NPC Model Builder
class NPCModelBuilder {
    static func buildPlayer(cls: CharacterClass) -> SCNNode {
        let root = SCNNode()
        let body = SCNCapsule(capRadius: CGFloat(0.15), height: CGFloat(0.5))
        body.firstMaterial?.diffuse.contents = NSColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1)
        let bodyNode = SCNNode(geometry: body); bodyNode.position = SCNVector3(CGFloat(0), CGFloat(0.25), CGFloat(0))
        let head = SCNSphere(radius: CGFloat(0.12))
        head.firstMaterial?.diffuse.contents = NSColor(red: 0.9, green: 0.75, blue: 0.6, alpha: 1)
        let headNode = SCNNode(geometry: head); headNode.position = SCNVector3(CGFloat(0), CGFloat(0.6), CGFloat(0))
        root.addChildNode(bodyNode); root.addChildNode(headNode)
        switch cls {
        case .fighter:
            let shield = SCNBox(width: CGFloat(0.15), height: CGFloat(0.2), length: CGFloat(0.04), chamferRadius: CGFloat(0))
            shield.firstMaterial?.diffuse.contents = NSColor.gray
            let sn = SCNNode(geometry: shield); sn.position = SCNVector3(CGFloat(-0.25), CGFloat(0.3), CGFloat(0)); root.addChildNode(sn)
            let sword = SCNCylinder(radius: CGFloat(0.02), height: CGFloat(0.35))
            sword.firstMaterial?.diffuse.contents = NSColor.lightGray
            let swn = SCNNode(geometry: sword); swn.position = SCNVector3(CGFloat(0.25), CGFloat(0.35), CGFloat(0)); root.addChildNode(swn)
        case .rogue:
            body.firstMaterial?.diffuse.contents = NSColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1)
            let dagger = SCNCylinder(radius: CGFloat(0.015), height: CGFloat(0.2))
            dagger.firstMaterial?.diffuse.contents = NSColor.lightGray
            let dn = SCNNode(geometry: dagger); dn.position = SCNVector3(CGFloat(0.2), CGFloat(0.3), CGFloat(0)); root.addChildNode(dn)
        case .cleric:
            body.firstMaterial?.diffuse.contents = NSColor.white
            let staff = SCNCylinder(radius: CGFloat(0.02), height: CGFloat(0.6))
            staff.firstMaterial?.diffuse.contents = NSColor.brown
            let stn = SCNNode(geometry: staff); stn.position = SCNVector3(CGFloat(0.2), CGFloat(0.3), CGFloat(0)); root.addChildNode(stn)
        case .wizard:
            body.firstMaterial?.diffuse.contents = NSColor.purple
            let hat = SCNCone(topRadius: CGFloat(0), bottomRadius: CGFloat(0.12), height: CGFloat(0.2))
            hat.firstMaterial?.diffuse.contents = NSColor.purple
            let hn = SCNNode(geometry: hat); hn.position = SCNVector3(CGFloat(0), CGFloat(0.75), CGFloat(0)); root.addChildNode(hn)
            let orb = SCNSphere(radius: CGFloat(0.05))
            orb.firstMaterial?.diffuse.contents = NSColor.cyan; orb.firstMaterial?.emission.contents = NSColor.cyan
            let on = SCNNode(geometry: orb); on.position = SCNVector3(CGFloat(0.2), CGFloat(0.4), CGFloat(0)); root.addChildNode(on)
        case .warlock:
            body.firstMaterial?.diffuse.contents = NSColor(red: 0.3, green: 0, blue: 0.3, alpha: 1)
            let orb = SCNSphere(radius: CGFloat(0.06))
            orb.firstMaterial?.diffuse.contents = NSColor.green; orb.firstMaterial?.emission.contents = NSColor.green
            let on = SCNNode(geometry: orb); on.position = SCNVector3(CGFloat(0.2), CGFloat(0.4), CGFloat(0)); root.addChildNode(on)
        }
        return root
    }

    static func buildNPC(race: String, name: String) -> SCNNode {
        let root = SCNNode()
        var skinColor = NSColor(red: 0.9, green: 0.75, blue: 0.6, alpha: 1)
        var bodyColor = NSColor.brown
        var bodyHeight: CGFloat = CGFloat(0.5); var bodyRadius: CGFloat = CGFloat(0.15)
        var headRadius: CGFloat = CGFloat(0.12)
        switch race {
        case "Elf":
            bodyColor = NSColor(red: 0.2, green: 0.6, blue: 0.3, alpha: 1)
            bodyHeight = CGFloat(0.6); headRadius = CGFloat(0.11)
            let body = SCNCapsule(capRadius: bodyRadius, height: bodyHeight)
            body.firstMaterial?.diffuse.contents = bodyColor
            let bn = SCNNode(geometry: body); bn.position = SCNVector3(CGFloat(0), CGFloat(0.3), CGFloat(0)); root.addChildNode(bn)
            let head = SCNSphere(radius: headRadius)
            head.firstMaterial?.diffuse.contents = skinColor
            let hn = SCNNode(geometry: head); hn.position = SCNVector3(CGFloat(0), CGFloat(0.7), CGFloat(0)); root.addChildNode(hn)
            // Elf ears
            let ear1 = SCNCone(topRadius: CGFloat(0), bottomRadius: CGFloat(0.03), height: CGFloat(0.08))
            ear1.firstMaterial?.diffuse.contents = skinColor
            let en1 = SCNNode(geometry: ear1); en1.position = SCNVector3(CGFloat(-0.12), CGFloat(0.72), CGFloat(0)); en1.eulerAngles = SCNVector3(CGFloat(0),CGFloat(0),CGFloat(Float.pi/4)); root.addChildNode(en1)
            let en2 = SCNNode(geometry: ear1); en2.position = SCNVector3(CGFloat(0.12), CGFloat(0.72), CGFloat(0)); en2.eulerAngles = SCNVector3(CGFloat(0),CGFloat(0),CGFloat(-Float.pi/4)); root.addChildNode(en2)
        case "Dwarf":
            bodyColor = NSColor(red: 0.5, green: 0.3, blue: 0.1, alpha: 1)
            bodyHeight = CGFloat(0.35); bodyRadius = CGFloat(0.18)
            let body = SCNBox(width: CGFloat(0.35), height: bodyHeight, length: CGFloat(0.25), chamferRadius: CGFloat(0.05))
            body.firstMaterial?.diffuse.contents = bodyColor
            let bn = SCNNode(geometry: body); bn.position = SCNVector3(CGFloat(0), CGFloat(0.175), CGFloat(0)); root.addChildNode(bn)
            let head = SCNSphere(radius: CGFloat(0.13))
            head.firstMaterial?.diffuse.contents = skinColor
            let hn = SCNNode(geometry: head); hn.position = SCNVector3(CGFloat(0), CGFloat(0.48), CGFloat(0)); root.addChildNode(hn)
            // Helmet
            let helmet = SCNSphere(radius: CGFloat(0.1))
            helmet.firstMaterial?.diffuse.contents = NSColor.gray
            let hln = SCNNode(geometry: helmet); hln.position = SCNVector3(CGFloat(0), CGFloat(0.56), CGFloat(0)); root.addChildNode(hln)
            // Beard
            let beard = SCNCylinder(radius: CGFloat(0.06), height: CGFloat(0.12))
            beard.firstMaterial?.diffuse.contents = NSColor(red: 0.6, green: 0.4, blue: 0.2, alpha: 1)
            let brn = SCNNode(geometry: beard); brn.position = SCNVector3(CGFloat(0), CGFloat(0.35), CGFloat(0.08)); root.addChildNode(brn)
        case "Halfling":
            skinColor = NSColor(red: 0.85, green: 0.7, blue: 0.55, alpha: 1)
            bodyColor = NSColor(red: 0.4, green: 0.6, blue: 0.2, alpha: 1)
            let body = SCNCapsule(capRadius: CGFloat(0.1), height: CGFloat(0.3))
            body.firstMaterial?.diffuse.contents = bodyColor
            let bn = SCNNode(geometry: body); bn.position = SCNVector3(CGFloat(0), CGFloat(0.15), CGFloat(0)); root.addChildNode(bn)
            let head = SCNSphere(radius: CGFloat(0.11))
            head.firstMaterial?.diffuse.contents = skinColor
            let hn = SCNNode(geometry: head); hn.position = SCNVector3(CGFloat(0), CGFloat(0.42), CGFloat(0)); root.addChildNode(hn)
            // Curly hair
            for i in 0..<4 {
                let curl = SCNSphere(radius: CGFloat(0.03))
                curl.firstMaterial?.diffuse.contents = NSColor.brown
                let cn = SCNNode(geometry: curl)
                let angle = CGFloat(Float(i)) * CGFloat(Float.pi/2)
                cn.position = SCNVector3(cos(angle)*CGFloat(0.1), CGFloat(0.5), sin(angle)*CGFloat(0.1))
                root.addChildNode(cn)
            }
        default: // Human
            let body = SCNCapsule(capRadius: bodyRadius, height: bodyHeight)
            body.firstMaterial?.diffuse.contents = bodyColor
            let bn = SCNNode(geometry: body); bn.position = SCNVector3(CGFloat(0), CGFloat(0.25), CGFloat(0)); root.addChildNode(bn)
            let head = SCNSphere(radius: headRadius)
            head.firstMaterial?.diffuse.contents = skinColor
            let hn = SCNNode(geometry: head); hn.position = SCNVector3(CGFloat(0), CGFloat(0.6), CGFloat(0)); root.addChildNode(hn)
        }
        // Idle bob animation
        let bob = SCNAction.sequence([
            SCNAction.moveBy(x: CGFloat(0), y: CGFloat(0.1), z: CGFloat(0), duration: 1.0),
            SCNAction.moveBy(x: CGFloat(0), y: CGFloat(-0.1), z: CGFloat(0), duration: 1.0)
        ])
        root.runAction(SCNAction.repeatForever(bob))
        return root
    }

    static func buildMonster(type: MonsterType) -> SCNNode {
        let root = SCNNode()
        switch type {
        case .giantRat:
            let body = SCNBox(width:CGFloat(0.3),height:CGFloat(0.15),length:CGFloat(0.2),chamferRadius:CGFloat(0.03))
            body.firstMaterial?.diffuse.contents = NSColor.brown
            let bn = SCNNode(geometry:body); bn.position=SCNVector3(CGFloat(0),CGFloat(0.1),CGFloat(0)); root.addChildNode(bn)
            let head = SCNSphere(radius:CGFloat(0.08)); head.firstMaterial?.diffuse.contents = NSColor.brown
            let hn = SCNNode(geometry:head); hn.position=SCNVector3(CGFloat(0.15),CGFloat(0.15),CGFloat(0)); root.addChildNode(hn)
            let tail = SCNCylinder(radius:CGFloat(0.01),height:CGFloat(0.2)); tail.firstMaterial?.diffuse.contents = NSColor(red:0.6,green:0.4,blue:0.3,alpha:1)
            let tn = SCNNode(geometry:tail); tn.position=SCNVector3(CGFloat(-0.2),CGFloat(0.1),CGFloat(0)); tn.eulerAngles=SCNVector3(CGFloat(0),CGFloat(0),CGFloat(Float.pi/4)); root.addChildNode(tn)
            let ear1 = SCNSphere(radius:CGFloat(0.03)); ear1.firstMaterial?.diffuse.contents = NSColor(red:0.8,green:0.5,blue:0.4,alpha:1)
            let en1 = SCNNode(geometry:ear1); en1.position=SCNVector3(CGFloat(0.15),CGFloat(0.22),CGFloat(0.05)); root.addChildNode(en1)
            let en2 = SCNNode(geometry:ear1); en2.position=SCNVector3(CGFloat(0.15),CGFloat(0.22),CGFloat(-0.05)); root.addChildNode(en2)
        case .goblin:
            let body = SCNCapsule(capRadius:CGFloat(0.1),height:CGFloat(0.3))
            body.firstMaterial?.diffuse.contents = NSColor(red:0.2,green:0.6,blue:0.2,alpha:1)
            let bn = SCNNode(geometry:body); bn.position=SCNVector3(CGFloat(0),CGFloat(0.15),CGFloat(0)); root.addChildNode(bn)
            let head = SCNSphere(radius:CGFloat(0.09)); head.firstMaterial?.diffuse.contents = NSColor(red:0.3,green:0.7,blue:0.3,alpha:1)
            let hn = SCNNode(geometry:head); hn.position=SCNVector3(CGFloat(0),CGFloat(0.4),CGFloat(0)); root.addChildNode(hn)
            let ear1 = SCNCylinder(radius:CGFloat(0.02),height:CGFloat(0.08)); ear1.firstMaterial?.diffuse.contents = NSColor(red:0.3,green:0.7,blue:0.3,alpha:1)
            let en1 = SCNNode(geometry:ear1); en1.position=SCNVector3(CGFloat(-0.09),CGFloat(0.44),CGFloat(0)); en1.eulerAngles=SCNVector3(CGFloat(0),CGFloat(0),CGFloat(Float.pi/3)); root.addChildNode(en1)
            let en2 = SCNNode(geometry:ear1); en2.position=SCNVector3(CGFloat(0.09),CGFloat(0.44),CGFloat(0)); en2.eulerAngles=SCNVector3(CGFloat(0),CGFloat(0),CGFloat(-Float.pi/3)); root.addChildNode(en2)
            let dagger = SCNCylinder(radius:CGFloat(0.015),height:CGFloat(0.15)); dagger.firstMaterial?.diffuse.contents = NSColor.lightGray
            let dn = SCNNode(geometry:dagger); dn.position=SCNVector3(CGFloat(0.15),CGFloat(0.2),CGFloat(0)); root.addChildNode(dn)
        case .skeletonWarrior:
            let torso = SCNBox(width:CGFloat(0.2),height:CGFloat(0.25),length:CGFloat(0.1),chamferRadius:CGFloat(0))
            torso.firstMaterial?.diffuse.contents = NSColor(white:0.9,alpha:1)
            let tn = SCNNode(geometry:torso); tn.position=SCNVector3(CGFloat(0),CGFloat(0.25),CGFloat(0)); root.addChildNode(tn)
            let skull = SCNSphere(radius:CGFloat(0.1)); skull.firstMaterial?.diffuse.contents = NSColor(white:0.95,alpha:1)
            let sn = SCNNode(geometry:skull); sn.position=SCNVector3(CGFloat(0),CGFloat(0.5),CGFloat(0)); root.addChildNode(sn)
            let eye1 = SCNSphere(radius:CGFloat(0.02)); eye1.firstMaterial?.diffuse.contents = NSColor.red; eye1.firstMaterial?.emission.contents = NSColor.red
            let eyn1 = SCNNode(geometry:eye1); eyn1.position=SCNVector3(CGFloat(-0.04),CGFloat(0.52),CGFloat(0.08)); root.addChildNode(eyn1)
            let eyn2 = SCNNode(geometry:eye1); eyn2.position=SCNVector3(CGFloat(0.04),CGFloat(0.52),CGFloat(0.08)); root.addChildNode(eyn2)
            let sword = SCNCylinder(radius:CGFloat(0.02),height:CGFloat(0.3)); sword.firstMaterial?.diffuse.contents = NSColor.lightGray
            let swn = SCNNode(geometry:sword); swn.position=SCNVector3(CGFloat(0.2),CGFloat(0.25),CGFloat(0)); root.addChildNode(swn)
            let shield = SCNBox(width:CGFloat(0.12),height:CGFloat(0.15),length:CGFloat(0.03),chamferRadius:CGFloat(0))
            shield.firstMaterial?.diffuse.contents = NSColor.darkGray
            let shn = SCNNode(geometry:shield); shn.position=SCNVector3(CGFloat(-0.2),CGFloat(0.25),CGFloat(0)); root.addChildNode(shn)
        case .skeletonArcher:
            let torso = SCNBox(width:CGFloat(0.2),height:CGFloat(0.25),length:CGFloat(0.1),chamferRadius:CGFloat(0))
            torso.firstMaterial?.diffuse.contents = NSColor(white:0.9,alpha:1)
            let tn = SCNNode(geometry:torso); tn.position=SCNVector3(CGFloat(0),CGFloat(0.25),CGFloat(0)); root.addChildNode(tn)
            let skull = SCNSphere(radius:CGFloat(0.1)); skull.firstMaterial?.diffuse.contents = NSColor(white:0.95,alpha:1)
            let sn = SCNNode(geometry:skull); sn.position=SCNVector3(CGFloat(0),CGFloat(0.5),CGFloat(0)); root.addChildNode(sn)
            let eye1 = SCNSphere(radius:CGFloat(0.02)); eye1.firstMaterial?.diffuse.contents = NSColor.red; eye1.firstMaterial?.emission.contents = NSColor.red
            let eyn1 = SCNNode(geometry:eye1); eyn1.position=SCNVector3(CGFloat(-0.04),CGFloat(0.52),CGFloat(0.08)); root.addChildNode(eyn1)
            let eyn2 = SCNNode(geometry:eye1); eyn2.position=SCNVector3(CGFloat(0.04),CGFloat(0.52),CGFloat(0.08)); root.addChildNode(eyn2)
            let bow = SCNTorus(ringRadius:CGFloat(0.12),pipeRadius:CGFloat(0.01)); bow.firstMaterial?.diffuse.contents = NSColor.brown
            let bwn = SCNNode(geometry:bow); bwn.position=SCNVector3(CGFloat(-0.15),CGFloat(0.3),CGFloat(0)); bwn.eulerAngles=SCNVector3(CGFloat(Float.pi/2),CGFloat(0),CGFloat(0)); root.addChildNode(bwn)
        case .orcBerserker:
            let body = SCNCapsule(capRadius:CGFloat(0.18),height:CGFloat(0.55))
            body.firstMaterial?.diffuse.contents = NSColor(red:0.2,green:0.5,blue:0.2,alpha:1)
            let bn = SCNNode(geometry:body); bn.position=SCNVector3(CGFloat(0),CGFloat(0.28),CGFloat(0)); root.addChildNode(bn)
            let head = SCNSphere(radius:CGFloat(0.13)); head.firstMaterial?.diffuse.contents = NSColor(red:0.3,green:0.55,blue:0.3,alpha:1)
            let hn = SCNNode(geometry:head); hn.position=SCNVector3(CGFloat(0),CGFloat(0.65),CGFloat(0)); root.addChildNode(hn)
            let jaw = SCNBox(width:CGFloat(0.08),height:CGFloat(0.04),length:CGFloat(0.04),chamferRadius:CGFloat(0))
            jaw.firstMaterial?.diffuse.contents = NSColor(white:0.9,alpha:1)
            let jn = SCNNode(geometry:jaw); jn.position=SCNVector3(CGFloat(0),CGFloat(0.58),CGFloat(0.1)); root.addChildNode(jn)
            let axe = SCNCylinder(radius:CGFloat(0.025),height:CGFloat(0.5)); axe.firstMaterial?.diffuse.contents = NSColor.brown
            let an = SCNNode(geometry:axe); an.position=SCNVector3(CGFloat(0.25),CGFloat(0.35),CGFloat(0)); root.addChildNode(an)
            let axeHead = SCNBox(width:CGFloat(0.15),height:CGFloat(0.1),length:CGFloat(0.02),chamferRadius:CGFloat(0))
            axeHead.firstMaterial?.diffuse.contents = NSColor.gray
            let ahn = SCNNode(geometry:axeHead); ahn.position=SCNVector3(CGFloat(0.25),CGFloat(0.58),CGFloat(0)); root.addChildNode(ahn)
        case .giantSpider:
            let body = SCNSphere(radius:CGFloat(0.18)); body.firstMaterial?.diffuse.contents = NSColor(red:0.15,green:0.1,blue:0.05,alpha:1)
            let bn = SCNNode(geometry:body); bn.position=SCNVector3(CGFloat(0),CGFloat(0.2),CGFloat(0)); root.addChildNode(bn)
            let head = SCNSphere(radius:CGFloat(0.08)); head.firstMaterial?.diffuse.contents = NSColor(red:0.15,green:0.1,blue:0.05,alpha:1)
            let hn = SCNNode(geometry:head); hn.position=SCNVector3(CGFloat(0.18),CGFloat(0.22),CGFloat(0)); root.addChildNode(hn)
            let eye = SCNSphere(radius:CGFloat(0.02)); eye.firstMaterial?.diffuse.contents = NSColor.red; eye.firstMaterial?.emission.contents = NSColor.red
            let eyn = SCNNode(geometry:eye); eyn.position=SCNVector3(CGFloat(0.24),CGFloat(0.25),CGFloat(0)); root.addChildNode(eyn)
            for i in 0..<8 {
                let leg = SCNCylinder(radius:CGFloat(0.01),height:CGFloat(0.25)); leg.firstMaterial?.diffuse.contents = NSColor(red:0.15,green:0.1,blue:0.05,alpha:1)
                let ln = SCNNode(geometry:leg)
                let angle = CGFloat(Float(i)) * CGFloat(Float.pi/4)
                ln.position = SCNVector3(cos(angle)*CGFloat(0.15), CGFloat(0.1), sin(angle)*CGFloat(0.15))
                ln.eulerAngles = SCNVector3(CGFloat(0),CGFloat(0),angle*CGFloat(0.3)+CGFloat(Float.pi/6))
                root.addChildNode(ln)
            }
        case .darkMage:
            let robe = SCNCone(topRadius:CGFloat(0.05),bottomRadius:CGFloat(0.2),height:CGFloat(0.5))
            robe.firstMaterial?.diffuse.contents = NSColor(red:0.3,green:0,blue:0.4,alpha:1)
            let rn = SCNNode(geometry:robe); rn.position=SCNVector3(CGFloat(0),CGFloat(0.25),CGFloat(0)); root.addChildNode(rn)
            let head = SCNSphere(radius:CGFloat(0.1)); head.firstMaterial?.diffuse.contents = NSColor(red:0.5,green:0.5,blue:0.6,alpha:1)
            let hn = SCNNode(geometry:head); hn.position=SCNVector3(CGFloat(0),CGFloat(0.58),CGFloat(0)); root.addChildNode(hn)
            let hat = SCNCone(topRadius:CGFloat(0),bottomRadius:CGFloat(0.12),height:CGFloat(0.2))
            hat.firstMaterial?.diffuse.contents = NSColor(red:0.3,green:0,blue:0.4,alpha:1)
            let htn = SCNNode(geometry:hat); htn.position=SCNVector3(CGFloat(0),CGFloat(0.72),CGFloat(0)); root.addChildNode(htn)
            let orb = SCNSphere(radius:CGFloat(0.05)); orb.firstMaterial?.diffuse.contents = NSColor.purple; orb.firstMaterial?.emission.contents = NSColor.purple
            let on = SCNNode(geometry:orb); on.position=SCNVector3(CGFloat(0.2),CGFloat(0.4),CGFloat(0))
            let pulse = SCNAction.sequence([SCNAction.scale(to:CGFloat(1.3),duration:0.5),SCNAction.scale(to:CGFloat(1.0),duration:0.5)])
            on.runAction(SCNAction.repeatForever(pulse)); root.addChildNode(on)
        case .troll:
            let body = SCNBox(width:CGFloat(0.35),height:CGFloat(0.6),length:CGFloat(0.3),chamferRadius:CGFloat(0.05))
            body.firstMaterial?.diffuse.contents = NSColor(red:0.2,green:0.5,blue:0.2,alpha:1)
            let bn = SCNNode(geometry:body); bn.position=SCNVector3(CGFloat(0),CGFloat(0.3),CGFloat(0)); root.addChildNode(bn)
            let head = SCNSphere(radius:CGFloat(0.1)); head.firstMaterial?.diffuse.contents = NSColor(red:0.25,green:0.55,blue:0.25,alpha:1)
            let hn = SCNNode(geometry:head); hn.position=SCNVector3(CGFloat(0),CGFloat(0.7),CGFloat(0)); root.addChildNode(hn)
            let arm1 = SCNCylinder(radius:CGFloat(0.05),height:CGFloat(0.4)); arm1.firstMaterial?.diffuse.contents = NSColor(red:0.2,green:0.5,blue:0.2,alpha:1)
            let an1 = SCNNode(geometry:arm1); an1.position=SCNVector3(CGFloat(-0.25),CGFloat(0.3),CGFloat(0)); an1.eulerAngles=SCNVector3(CGFloat(0),CGFloat(0),CGFloat(Float.pi/6)); root.addChildNode(an1)
            let an2 = SCNNode(geometry:arm1); an2.position=SCNVector3(CGFloat(0.25),CGFloat(0.3),CGFloat(0)); an2.eulerAngles=SCNVector3(CGFloat(0),CGFloat(0),CGFloat(-Float.pi/6)); root.addChildNode(an2)
        case .mimic:
            let chest = SCNBox(width:CGFloat(0.3),height:CGFloat(0.25),length:CGFloat(0.2),chamferRadius:CGFloat(0.02))
            chest.firstMaterial?.diffuse.contents = NSColor(red:0.7,green:0.5,blue:0.1,alpha:1)
            let cn = SCNNode(geometry:chest); cn.position=SCNVector3(CGFloat(0),CGFloat(0.125),CGFloat(0)); root.addChildNode(cn)
            let lid = SCNBox(width:CGFloat(0.3),height:CGFloat(0.05),length:CGFloat(0.2),chamferRadius:CGFloat(0.02))
            lid.firstMaterial?.diffuse.contents = NSColor(red:0.6,green:0.4,blue:0.05,alpha:1)
            let ln = SCNNode(geometry:lid); ln.position=SCNVector3(CGFloat(0),CGFloat(0.27),CGFloat(0)); root.addChildNode(ln)
        case .wraith:
            let body = SCNCone(topRadius:CGFloat(0.05),bottomRadius:CGFloat(0.2),height:CGFloat(0.6))
            body.firstMaterial?.diffuse.contents = NSColor(red:0.15,green:0.05,blue:0.2,alpha:0.6)
            let bn = SCNNode(geometry:body); bn.position=SCNVector3(CGFloat(0),CGFloat(0.3),CGFloat(0)); bn.opacity=CGFloat(0.6); root.addChildNode(bn)
            let eye1 = SCNSphere(radius:CGFloat(0.03)); eye1.firstMaterial?.diffuse.contents = NSColor.purple; eye1.firstMaterial?.emission.contents = NSColor.purple
            let eyn1 = SCNNode(geometry:eye1); eyn1.position=SCNVector3(CGFloat(-0.04),CGFloat(0.55),CGFloat(0.06)); root.addChildNode(eyn1)
            let eyn2 = SCNNode(geometry:eye1); eyn2.position=SCNVector3(CGFloat(0.04),CGFloat(0.55),CGFloat(0.06)); root.addChildNode(eyn2)
            let float = SCNAction.sequence([SCNAction.moveBy(x:CGFloat(0),y:CGFloat(0.15),z:CGFloat(0),duration:1.5),SCNAction.moveBy(x:CGFloat(0),y:CGFloat(-0.15),z:CGFloat(0),duration:1.5)])
            root.runAction(SCNAction.repeatForever(float))
        case .ogre:
            let body = SCNBox(width:CGFloat(0.45),height:CGFloat(0.7),length:CGFloat(0.35),chamferRadius:CGFloat(0.05))
            body.firstMaterial?.diffuse.contents = NSColor(red:0.5,green:0.4,blue:0.3,alpha:1)
            let bn = SCNNode(geometry:body); bn.position=SCNVector3(CGFloat(0),CGFloat(0.35),CGFloat(0)); root.addChildNode(bn)
            let head = SCNSphere(radius:CGFloat(0.1)); head.firstMaterial?.diffuse.contents = NSColor(red:0.55,green:0.45,blue:0.35,alpha:1)
            let hn = SCNNode(geometry:head); hn.position=SCNVector3(CGFloat(0),CGFloat(0.8),CGFloat(0)); root.addChildNode(hn)
            let club = SCNCylinder(radius:CGFloat(0.04),height:CGFloat(0.5)); club.firstMaterial?.diffuse.contents = NSColor.brown
            let cln = SCNNode(geometry:club); cln.position=SCNVector3(CGFloat(0.3),CGFloat(0.3),CGFloat(0)); root.addChildNode(cln)
            let leg1 = SCNCylinder(radius:CGFloat(0.08),height:CGFloat(0.25)); leg1.firstMaterial?.diffuse.contents = NSColor(red:0.45,green:0.35,blue:0.25,alpha:1)
            let lgn1 = SCNNode(geometry:leg1); lgn1.position=SCNVector3(CGFloat(-0.12),CGFloat(-0.05),CGFloat(0)); root.addChildNode(lgn1)
            let lgn2 = SCNNode(geometry:leg1); lgn2.position=SCNVector3(CGFloat(0.12),CGFloat(-0.05),CGFloat(0)); root.addChildNode(lgn2)
        case .youngDragon:
            let body = SCNBox(width:CGFloat(0.5),height:CGFloat(0.3),length:CGFloat(0.7),chamferRadius:CGFloat(0.05))
            body.firstMaterial?.diffuse.contents = NSColor(red:0.6,green:0.1,blue:0.1,alpha:1)
            let bn = SCNNode(geometry:body); bn.position=SCNVector3(CGFloat(0),CGFloat(0.3),CGFloat(0)); root.addChildNode(bn)
            let head = SCNSphere(radius:CGFloat(0.15)); head.firstMaterial?.diffuse.contents = NSColor(red:0.65,green:0.15,blue:0.15,alpha:1)
            let hn = SCNNode(geometry:head); hn.position=SCNVector3(CGFloat(0),CGFloat(0.5),CGFloat(0.35)); root.addChildNode(hn)
            let horn1 = SCNCone(topRadius:CGFloat(0),bottomRadius:CGFloat(0.03),height:CGFloat(0.12))
            horn1.firstMaterial?.diffuse.contents = NSColor(white:0.8,alpha:1)
            let hrn1 = SCNNode(geometry:horn1); hrn1.position=SCNVector3(CGFloat(-0.06),CGFloat(0.65),CGFloat(0.35)); root.addChildNode(hrn1)
            let hrn2 = SCNNode(geometry:horn1); hrn2.position=SCNVector3(CGFloat(0.06),CGFloat(0.65),CGFloat(0.35)); root.addChildNode(hrn2)
            let eye1 = SCNSphere(radius:CGFloat(0.03)); eye1.firstMaterial?.diffuse.contents = NSColor.yellow; eye1.firstMaterial?.emission.contents = NSColor.yellow
            let eyn1 = SCNNode(geometry:eye1); eyn1.position=SCNVector3(CGFloat(-0.07),CGFloat(0.53),CGFloat(0.45)); root.addChildNode(eyn1)
            let eyn2 = SCNNode(geometry:eye1); eyn2.position=SCNVector3(CGFloat(0.07),CGFloat(0.53),CGFloat(0.45)); root.addChildNode(eyn2)
            // Wings
            let wing1 = SCNBox(width:CGFloat(0.4),height:CGFloat(0.02),length:CGFloat(0.3),chamferRadius:CGFloat(0))
            wing1.firstMaterial?.diffuse.contents = NSColor(red:0.5,green:0.08,blue:0.08,alpha:0.8)
            let wn1 = SCNNode(geometry:wing1); wn1.position=SCNVector3(CGFloat(-0.35),CGFloat(0.4),CGFloat(0)); wn1.eulerAngles=SCNVector3(CGFloat(0),CGFloat(0),CGFloat(Float.pi/8)); root.addChildNode(wn1)
            let wn2 = SCNNode(geometry:wing1); wn2.position=SCNVector3(CGFloat(0.35),CGFloat(0.4),CGFloat(0)); wn2.eulerAngles=SCNVector3(CGFloat(0),CGFloat(0),CGFloat(-Float.pi/8)); root.addChildNode(wn2)
            // Tail
            let tail1 = SCNCylinder(radius:CGFloat(0.04),height:CGFloat(0.25)); tail1.firstMaterial?.diffuse.contents = NSColor(red:0.6,green:0.1,blue:0.1,alpha:1)
            let tln1 = SCNNode(geometry:tail1); tln1.position=SCNVector3(CGFloat(0),CGFloat(0.25),CGFloat(-0.4)); tln1.eulerAngles=SCNVector3(CGFloat(Float.pi/4),CGFloat(0),CGFloat(0)); root.addChildNode(tln1)
            let tail2 = SCNCylinder(radius:CGFloat(0.03),height:CGFloat(0.2)); tail2.firstMaterial?.diffuse.contents = NSColor(red:0.6,green:0.1,blue:0.1,alpha:1)
            let tln2 = SCNNode(geometry:tail2); tln2.position=SCNVector3(CGFloat(0),CGFloat(0.15),CGFloat(-0.55)); tln2.eulerAngles=SCNVector3(CGFloat(Float.pi/3),CGFloat(0),CGFloat(0)); root.addChildNode(tln2)
            // Wing flap
            let flap1 = SCNAction.sequence([SCNAction.rotateTo(x:CGFloat(0),y:CGFloat(0),z:CGFloat(Float.pi/6),duration:0.8),SCNAction.rotateTo(x:CGFloat(0),y:CGFloat(0),z:CGFloat(Float.pi/12),duration:0.8)])
            wn1.runAction(SCNAction.repeatForever(flap1))
            let flap2 = SCNAction.sequence([SCNAction.rotateTo(x:CGFloat(0),y:CGFloat(0),z:CGFloat(-Float.pi/6),duration:0.8),SCNAction.rotateTo(x:CGFloat(0),y:CGFloat(0),z:CGFloat(-Float.pi/12),duration:0.8)])
            wn2.runAction(SCNAction.repeatForever(flap2))
        }
        return root
    }
}

// MARK: - BFS Pathfinding
func bfsPath(grid: [[Int]], from: (Int,Int), to: (Int,Int), walkable: Set<Int> = [1,2,3,4,5]) -> [(Int,Int)] {
    let h = grid.count; let w = grid[0].count
    if from.0 == to.0 && from.1 == to.1 { return [] }
    if to.0 < 0 || to.0 >= w || to.1 < 0 || to.1 >= h { return [] }
    if !walkable.contains(grid[to.1][to.0]) { return [] }
    var visited = Array(repeating: Array(repeating: false, count: w), count: h)
    var parent: [String: (Int,Int)?] = [:]
    var queue: [(Int,Int)] = [(from.0, from.1)]
    visited[from.1][from.0] = true
    let dirs = [(-1,0),(1,0),(0,-1),(0,1),(-1,-1),(-1,1),(1,-1),(1,1)]
    while !queue.isEmpty {
        let cur = queue.removeFirst()
        if cur.0 == to.0 && cur.1 == to.1 {
            var path: [(Int,Int)] = []
            var c: (Int,Int)? = cur
            while let cc = c, !(cc.0 == from.0 && cc.1 == from.1) {
                path.append(cc)
                c = parent["\(cc.0),\(cc.1)"] ?? nil
            }
            return path.reversed()
        }
        for d in dirs {
            let nx = cur.0 + d.0; let ny = cur.1 + d.1
            if nx >= 0 && nx < w && ny >= 0 && ny < h && !visited[ny][nx] && walkable.contains(grid[ny][nx]) {
                visited[ny][nx] = true
                parent["\(nx),\(ny)"] = cur
                queue.append((nx,ny))
            }
        }
    }
    return []
}

// MARK: - Game Controller
class GameController: NSObject {
    // Scene references
    let scnView: SCNView
    let scene: SCNScene
    let overlay: SKScene
    let cameraNode: SCNNode

    // Game state
    var state: GameState = .mainMenu
    var player = PlayerCharacter()
    var monsters: [MonsterCharacter] = []
    var currentLocation: LocationID = .oakvale
    var locations: [LocationID: LocationData] = [:]
    var allNPCs: [NPCData] = []

    // Dungeon
    var dungeonGen = DungeonGenerator()
    var currentDungeon: String = ""
    var currentFloor: Int = 1
    var maxFloors: Int = 3
    var dungeonTileNodes: [SCNNode] = []
    var inCombat: Bool = false
    var currentMonsterIndex: Int = 0

    // Village
    var villageNodes: [SCNNode] = []
    var npcNodes: [(npc: NPCData, node: SCNNode)] = []
    var buildingNodes: [(building: BuildingData, node: SCNNode)] = []

    // World map overlay nodes
    var worldMapNodes: [SKNode] = []

    // HUD elements
    var narrationLines: [String] = []
    var narrationNode: SKLabelNode!
    var topBarBg: SKShapeNode!; var topLocationLabel: SKLabelNode!; var topChapterLabel: SKLabelNode!; var topGoldLabel: SKLabelNode!
    var rightPanelBg: SKShapeNode!; var rightTitleLabel: SKLabelNode!
    var narrationLabels: [SKLabelNode] = []
    var bottomBarBg: SKShapeNode!; var bottomLabel: SKLabelNode!
    var charPanelBg: SKShapeNode!; var charClassLabel: SKLabelNode!; var charHPLabel: SKLabelNode!; var charACLabel: SKLabelNode!; var charEffectsLabel: SKLabelNode!
    var hpBarBg: SKShapeNode!; var hpBarFill: SKShapeNode!

    // Dialogue
    var dialogueBg: SKShapeNode!; var dialogueNameLabel: SKLabelNode!; var dialogueTextLabel: SKLabelNode!
    var dialogueButtons: [SKShapeNode] = []; var dialogueButtonLabels: [SKLabelNode] = []
    var currentDialogueNPC: NPCData?; var currentDialogueResponses: [DialogueOption] = []

    // Quest board
    var questBoardNodes: [SKNode] = []
    var availableQuests: [Quest] = []

    // Shop
    var shopNodes: [SKNode] = []
    var shopItems: [Item] = []
    var shopType: String = ""

    // Menu
    var menuNodes: [SKNode] = []
    var classButtons: [SKShapeNode] = []; var classButtonLabels: [SKLabelNode] = []

    // Inventory
    var inventoryNodes: [SKNode] = []

    // Combat UI
    var abilityButtons: [SKShapeNode] = []; var abilityLabels: [SKLabelNode] = []
    var turnIndicatorLabel: SKLabelNode!

    // Traveling
    var travelDestination: LocationID?

    // Timing
    var lastUpdate: TimeInterval = 0

    // MARK: - Init
    init(scnView: SCNView) {
        self.scnView = scnView
        self.scene = SCNScene()
        self.overlay = SKScene(size: CGSize(width: 1280, height: 720))
        self.cameraNode = SCNNode()
        self.locations = buildLocationData()
        self.allNPCs = buildNPCData()
        super.init()

        scnView.scene = scene
        overlay.scaleMode = .resizeFill
        scnView.overlaySKScene = overlay

        // Camera
        let camera = SCNCamera(); camera.zNear = 0.1; camera.zFar = 100
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(CGFloat(8), CGFloat(12), CGFloat(18))
        cameraNode.look(at: SCNVector3(CGFloat(8), CGFloat(0), CGFloat(8)))
        scene.rootNode.addChildNode(cameraNode)

        // Lighting
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight(); ambientLight.light!.type = .ambient
        ambientLight.light!.color = NSColor(white: 0.4, alpha: 1)
        scene.rootNode.addChildNode(ambientLight)
        let dirLight = SCNNode()
        dirLight.light = SCNLight(); dirLight.light!.type = .directional
        dirLight.light!.color = NSColor(white: 0.8, alpha: 1)
        dirLight.eulerAngles = SCNVector3(CGFloat(-Float.pi/3), CGFloat(Float.pi/4), CGFloat(0))
        scene.rootNode.addChildNode(dirLight)

        scene.background.contents = NSColor(red: 0.05, green: 0.05, blue: 0.1, alpha: 1)

        setupHUD()
        showMainMenu()
    }

    // MARK: - HUD Setup
    func setupHUD() {
        // Top bar
        topBarBg = SKShapeNode(rect: CGRect(x: 0, y: 660, width: 1280, height: 60))
        topBarBg.fillColor = NSColor(red: 0.1, green: 0.08, blue: 0.06, alpha: 0.85)
        topBarBg.strokeColor = NSColor(red: 0.6, green: 0.5, blue: 0.2, alpha: 1)
        topBarBg.lineWidth = 1; overlay.addChild(topBarBg)

        topLocationLabel = SKLabelNode(fontNamed: "Menlo-Bold"); topLocationLabel.fontSize = 16
        topLocationLabel.fontColor = NSColor(red: 1, green: 0.85, blue: 0.3, alpha: 1)
        topLocationLabel.position = CGPoint(x: 120, y: 685); topLocationLabel.horizontalAlignmentMode = .left
        overlay.addChild(topLocationLabel)

        topChapterLabel = SKLabelNode(fontNamed: "Menlo"); topChapterLabel.fontSize = 13
        topChapterLabel.fontColor = NSColor(white: 0.8, alpha: 1)
        topChapterLabel.position = CGPoint(x: 640, y: 685); topChapterLabel.horizontalAlignmentMode = .center
        overlay.addChild(topChapterLabel)

        topGoldLabel = SKLabelNode(fontNamed: "Menlo-Bold"); topGoldLabel.fontSize = 14
        topGoldLabel.fontColor = NSColor(red: 1, green: 0.9, blue: 0.3, alpha: 1)
        topGoldLabel.position = CGPoint(x: 1160, y: 685); topGoldLabel.horizontalAlignmentMode = .right
        overlay.addChild(topGoldLabel)

        // Right panel
        rightPanelBg = SKShapeNode(rect: CGRect(x: 900, y: 80, width: 370, height: 570))
        rightPanelBg.fillColor = NSColor(red: 0.08, green: 0.06, blue: 0.1, alpha: 0.8)
        rightPanelBg.strokeColor = NSColor(red: 0.4, green: 0.3, blue: 0.5, alpha: 0.8)
        rightPanelBg.lineWidth = 1; overlay.addChild(rightPanelBg)

        rightTitleLabel = SKLabelNode(fontNamed: "Menlo-Bold"); rightTitleLabel.fontSize = 14
        rightTitleLabel.fontColor = NSColor(red: 0.8, green: 0.7, blue: 1, alpha: 1)
        rightTitleLabel.position = CGPoint(x: 1085, y: 625); rightTitleLabel.horizontalAlignmentMode = .center
        rightTitleLabel.text = "JOURNAL"; overlay.addChild(rightTitleLabel)

        for i in 0..<10 {
            let lbl = SKLabelNode(fontNamed: "Menlo"); lbl.fontSize = 11
            lbl.fontColor = NSColor(white: 0.75, alpha: 1)
            lbl.position = CGPoint(x: 912, y: 600 - i * 18); lbl.horizontalAlignmentMode = .left
            lbl.preferredMaxLayoutWidth = 350
            lbl.numberOfLines = 0
            overlay.addChild(lbl)
            narrationLabels.append(lbl)
        }

        // Bottom bar
        bottomBarBg = SKShapeNode(rect: CGRect(x: 0, y: 0, width: 1280, height: 60))
        bottomBarBg.fillColor = NSColor(red: 0.1, green: 0.08, blue: 0.06, alpha: 0.85)
        bottomBarBg.strokeColor = NSColor(red: 0.5, green: 0.4, blue: 0.2, alpha: 0.8)
        bottomBarBg.lineWidth = 1; overlay.addChild(bottomBarBg)

        bottomLabel = SKLabelNode(fontNamed: "Menlo"); bottomLabel.fontSize = 12
        bottomLabel.fontColor = NSColor(white: 0.7, alpha: 1)
        bottomLabel.position = CGPoint(x: 20, y: 25); bottomLabel.horizontalAlignmentMode = .left
        overlay.addChild(bottomLabel)

        // Character panel (top-left)
        charPanelBg = SKShapeNode(rect: CGRect(x: 10, y: 560, width: 200, height: 90))
        charPanelBg.fillColor = NSColor(red: 0.08, green: 0.06, blue: 0.1, alpha: 0.8)
        charPanelBg.strokeColor = NSColor(red: 0.4, green: 0.3, blue: 0.5, alpha: 0.6)
        charPanelBg.lineWidth = 1; overlay.addChild(charPanelBg)

        charClassLabel = SKLabelNode(fontNamed: "Menlo-Bold"); charClassLabel.fontSize = 12
        charClassLabel.fontColor = NSColor(white: 0.9, alpha: 1)
        charClassLabel.position = CGPoint(x: 20, y: 630); charClassLabel.horizontalAlignmentMode = .left
        overlay.addChild(charClassLabel)

        charHPLabel = SKLabelNode(fontNamed: "Menlo"); charHPLabel.fontSize = 11
        charHPLabel.fontColor = NSColor(red: 1, green: 0.4, blue: 0.4, alpha: 1)
        charHPLabel.position = CGPoint(x: 20, y: 610); charHPLabel.horizontalAlignmentMode = .left
        overlay.addChild(charHPLabel)

        hpBarBg = SKShapeNode(rect: CGRect(x: 20, y: 598, width: 180, height: 8))
        hpBarBg.fillColor = NSColor(red: 0.3, green: 0.1, blue: 0.1, alpha: 1)
        hpBarBg.strokeColor = .clear; overlay.addChild(hpBarBg)
        hpBarFill = SKShapeNode(rect: CGRect(x: 20, y: 598, width: 180, height: 8))
        hpBarFill.fillColor = NSColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 1)
        hpBarFill.strokeColor = .clear; overlay.addChild(hpBarFill)

        charACLabel = SKLabelNode(fontNamed: "Menlo"); charACLabel.fontSize = 11
        charACLabel.fontColor = NSColor(white: 0.7, alpha: 1)
        charACLabel.position = CGPoint(x: 20, y: 578); charACLabel.horizontalAlignmentMode = .left
        overlay.addChild(charACLabel)

        charEffectsLabel = SKLabelNode(fontNamed: "Menlo"); charEffectsLabel.fontSize = 10
        charEffectsLabel.fontColor = NSColor(red: 0.6, green: 0.8, blue: 1, alpha: 1)
        charEffectsLabel.position = CGPoint(x: 20, y: 563); charEffectsLabel.horizontalAlignmentMode = .left
        overlay.addChild(charEffectsLabel)

        // Turn indicator
        turnIndicatorLabel = SKLabelNode(fontNamed: "Menlo-Bold"); turnIndicatorLabel.fontSize = 18
        turnIndicatorLabel.fontColor = NSColor.yellow
        turnIndicatorLabel.position = CGPoint(x: 450, y: 680); turnIndicatorLabel.horizontalAlignmentMode = .center
        turnIndicatorLabel.isHidden = true; overlay.addChild(turnIndicatorLabel)

        // Dialogue overlay (hidden by default)
        dialogueBg = SKShapeNode(rect: CGRect(x: 200, y: 200, width: 680, height: 320), cornerRadius: 12)
        dialogueBg.fillColor = NSColor(red: 0.05, green: 0.03, blue: 0.08, alpha: 0.95)
        dialogueBg.strokeColor = NSColor(red: 0.6, green: 0.5, blue: 0.8, alpha: 1)
        dialogueBg.lineWidth = 2; dialogueBg.isHidden = true; overlay.addChild(dialogueBg)

        dialogueNameLabel = SKLabelNode(fontNamed: "Menlo-Bold"); dialogueNameLabel.fontSize = 16
        dialogueNameLabel.fontColor = NSColor(red: 1, green: 0.85, blue: 0.4, alpha: 1)
        dialogueNameLabel.position = CGPoint(x: 540, y: 490); dialogueNameLabel.horizontalAlignmentMode = .center
        dialogueNameLabel.isHidden = true; overlay.addChild(dialogueNameLabel)

        dialogueTextLabel = SKLabelNode(fontNamed: "Menlo"); dialogueTextLabel.fontSize = 13
        dialogueTextLabel.fontColor = NSColor(white: 0.85, alpha: 1)
        dialogueTextLabel.position = CGPoint(x: 230, y: 440); dialogueTextLabel.horizontalAlignmentMode = .left
        dialogueTextLabel.preferredMaxLayoutWidth = 620; dialogueTextLabel.numberOfLines = 0
        dialogueTextLabel.isHidden = true; overlay.addChild(dialogueTextLabel)

        hideAllHUD()
    }

    func hideAllHUD() {
        topBarBg.isHidden = true; topLocationLabel.isHidden = true; topChapterLabel.isHidden = true; topGoldLabel.isHidden = true
        rightPanelBg.isHidden = true; rightTitleLabel.isHidden = true
        for l in narrationLabels { l.isHidden = true }
        bottomBarBg.isHidden = true; bottomLabel.isHidden = true
        charPanelBg.isHidden = true; charClassLabel.isHidden = true; charHPLabel.isHidden = true
        hpBarBg.isHidden = true; hpBarFill.isHidden = true
        charACLabel.isHidden = true; charEffectsLabel.isHidden = true
        turnIndicatorLabel.isHidden = true
    }

    func showGameHUD() {
        topBarBg.isHidden = false; topLocationLabel.isHidden = false; topChapterLabel.isHidden = false; topGoldLabel.isHidden = false
        rightPanelBg.isHidden = false; rightTitleLabel.isHidden = false
        for l in narrationLabels { l.isHidden = false }
        bottomBarBg.isHidden = false; bottomLabel.isHidden = false
        charPanelBg.isHidden = false; charClassLabel.isHidden = false; charHPLabel.isHidden = false
        hpBarBg.isHidden = false; hpBarFill.isHidden = false
        charACLabel.isHidden = false; charEffectsLabel.isHidden = false
        updateHUD()
    }

    func updateHUD() {
        let loc = locations[currentLocation]
        topLocationLabel.text = loc?.name.uppercased() ?? ""
        if player.campaignChapter <= campaignChapters.count {
            topChapterLabel.text = "Chapter \(player.campaignChapter): \(campaignChapters[player.campaignChapter-1].title)"
        }
        topGoldLabel.text = "\(player.gold)g  Day \(player.day)"
        charClassLabel.text = "\(player.cls.rawValue) Lv\(player.level) (\(player.xp)/\(player.xpToNext) XP)"
        charHPLabel.text = "HP: \(player.hp)/\(player.maxHP)"
        charACLabel.text = "AC: \(player.effectiveAC)"
        let pct = CGFloat(max(0, player.hp)) / CGFloat(max(1, player.maxHP))
        hpBarFill.removeFromParent()
        hpBarFill = SKShapeNode(rect: CGRect(x: 20, y: 598, width: 180.0 * pct, height: 8))
        hpBarFill.fillColor = pct > 0.5 ? NSColor(red: 0.2, green: 0.8, blue: 0.2, alpha: 1) : (pct > 0.25 ? NSColor.yellow : NSColor.red)
        hpBarFill.strokeColor = .clear; overlay.addChild(hpBarFill)

        var effectStr = ""
        if player.cls == .wizard { effectStr += "Mana:\(player.mana)/\(player.maxMana) " }
        if player.cls == .warlock { effectStr += "Pact:\(player.pactPoints)/\(player.maxPactPoints) " }
        for e in player.effects { effectStr += "\(e.effect.rawValue)(\(e.turnsRemaining)) " }
        charEffectsLabel.text = effectStr

        // Update narration
        let startIdx = max(0, narrationLines.count - narrationLabels.count)
        for i in 0..<narrationLabels.count {
            let idx = startIdx + i
            narrationLabels[i].text = idx < narrationLines.count ? narrationLines[idx] : ""
        }

        // Bottom bar context
        switch state {
        case .village:
            bottomLabel.text = "[Click] Walk  [E] Interact  [I] Inventory  [M] Map  [Q] Quests"
        case .dungeon:
            bottomLabel.text = "[Click] Walk  [I] Inventory  [Q] Quests"
        case .combat:
            bottomLabel.text = "[Click] Move/Attack  [1-4] Abilities  [Space] End Turn"
        case .worldMap:
            bottomLabel.text = "[Click] Travel to location  [Esc] Return"
        default:
            bottomLabel.text = ""
        }
    }

    func addNarration(_ text: String) {
        narrationLines.append(text)
        if narrationLines.count > 50 { narrationLines.removeFirst() }
        updateHUD()
    }

    // MARK: - Main Menu
    func showMainMenu() {
        state = .mainMenu
        hideAllHUD()
        clearScene()

        // Title
        let titleBg = SKShapeNode(rect: CGRect(x: 0, y: 0, width: 1280, height: 720))
        titleBg.fillColor = NSColor(red: 0.03, green: 0.02, blue: 0.05, alpha: 1)
        titleBg.strokeColor = .clear; titleBg.name = "menu"; overlay.addChild(titleBg); menuNodes.append(titleBg)

        let title = SKLabelNode(fontNamed: "Menlo-Bold"); title.fontSize = 32
        title.fontColor = NSColor(red: 1, green: 0.85, blue: 0.3, alpha: 1)
        title.text = "DUNGEONS & DICE"; title.position = CGPoint(x: 640, y: 550)
        title.name = "menu"; overlay.addChild(title); menuNodes.append(title)

        let subtitle = SKLabelNode(fontNamed: "Menlo"); subtitle.fontSize = 16
        subtitle.fontColor = NSColor(white: 0.6, alpha: 1)
        subtitle.text = "Choose your class to begin the campaign"; subtitle.position = CGPoint(x: 640, y: 510)
        subtitle.name = "menu"; overlay.addChild(subtitle); menuNodes.append(subtitle)

        // Class buttons
        let classes: [(CharacterClass, String)] = [
            (.fighter, "FIGHTER (STR) - HP d10, AC 17"),
            (.rogue, "ROGUE (DEX) - HP d8, AC 15"),
            (.cleric, "CLERIC (WIS) - HP d8, AC 16"),
            (.wizard, "WIZARD (INT) - HP d6, AC 12"),
            (.warlock, "WARLOCK (CHA) - HP d8, AC 13"),
        ]
        classButtons = []; classButtonLabels = []
        for (i, (cls, desc)) in classes.enumerated() {
            let y = CGFloat(400 - i * 60)
            let btn = SKShapeNode(rect: CGRect(x: 370, y: y - 18, width: 540, height: 44), cornerRadius: 6)
            btn.fillColor = NSColor(red: 0.15, green: 0.12, blue: 0.2, alpha: 0.9)
            btn.strokeColor = NSColor(red: 0.5, green: 0.4, blue: 0.7, alpha: 0.8)
            btn.name = "class_\(cls.rawValue)"; overlay.addChild(btn); menuNodes.append(btn); classButtons.append(btn)
            let lbl = SKLabelNode(fontNamed: "Menlo"); lbl.fontSize = 14
            lbl.fontColor = NSColor(white: 0.9, alpha: 1); lbl.text = desc
            lbl.position = CGPoint(x: 640, y: y - 5); lbl.name = "class_\(cls.rawValue)"
            overlay.addChild(lbl); menuNodes.append(lbl); classButtonLabels.append(lbl)
        }
    }

    func selectClass(_ cls: CharacterClass) {
        for n in menuNodes { n.removeFromParent() }; menuNodes.removeAll()
        player.initialize(cls: cls)
        currentLocation = .oakvale
        player.campaignChapter = 1
        narrationLines.removeAll()
        addNarration(campaignChapters[0].intro)
        addNarration("Objective: \(campaignChapters[0].objective)")
        showGameHUD()
        enterVillage(currentLocation)
    }

    // MARK: - Clear Scene
    func clearScene() {
        for n in dungeonTileNodes { n.removeFromParentNode() }; dungeonTileNodes.removeAll()
        for n in villageNodes { n.removeFromParentNode() }; villageNodes.removeAll()
        for (_, n) in npcNodes { n.removeFromParentNode() }; npcNodes.removeAll()
        for (_, n) in buildingNodes { n.removeFromParentNode() }; buildingNodes.removeAll()
        player.node?.removeFromParentNode()
        for m in monsters { m.node?.removeFromParentNode() }; monsters.removeAll()
        player.familiarNode?.removeFromParentNode()
    }

    // MARK: - Village
    func enterVillage(_ locID: LocationID) {
        clearScene()
        state = .village
        currentLocation = locID
        inCombat = false
        guard let loc = locations[locID] else { return }

        addNarration(loc.description)

        // Ground plane
        let ground = SCNFloor()
        ground.firstMaterial?.diffuse.contents = locID == .silverwood ? NSColor(red:0.15,green:0.3,blue:0.1,alpha:1)
            : locID == .ironhold ? NSColor(red:0.3,green:0.25,blue:0.2,alpha:1)
            : locID == .marshfen ? NSColor(red:0.2,green:0.25,blue:0.15,alpha:1)
            : NSColor(red:0.2,green:0.35,blue:0.15,alpha:1)
        let groundNode = SCNNode(geometry: ground)
        scene.rootNode.addChildNode(groundNode); villageNodes.append(groundNode)

        // Buildings
        for b in loc.buildings {
            let bw = CGFloat(b.width); let bd = CGFloat(b.depth); let bh = CGFloat(2.0)
            let box = SCNBox(width: bw, height: bh, length: bd, chamferRadius: CGFloat(0.1))
            let buildingColor: NSColor
            switch b.type {
            case .inn: buildingColor = NSColor(red:0.5,green:0.3,blue:0.15,alpha:1)
            case .guild: buildingColor = NSColor(red:0.3,green:0.3,blue:0.5,alpha:1)
            case .generalShop, .herbShop: buildingColor = NSColor(red:0.4,green:0.35,blue:0.2,alpha:1)
            case .blacksmith, .masterForge: buildingColor = NSColor(red:0.35,green:0.25,blue:0.2,alpha:1)
            case .druidCircle: buildingColor = NSColor(red:0.2,green:0.4,blue:0.25,alpha:1)
            case .aleHall: buildingColor = NSColor(red:0.45,green:0.3,blue:0.1,alpha:1)
            default: buildingColor = NSColor(red:0.3,green:0.3,blue:0.3,alpha:1)
            }
            box.firstMaterial?.diffuse.contents = buildingColor
            let bNode = SCNNode(geometry: box)
            bNode.position = SCNVector3(CGFloat(b.gridX) + bw/CGFloat(2), bh/CGFloat(2), CGFloat(b.gridZ) + bd/CGFloat(2))
            scene.rootNode.addChildNode(bNode); villageNodes.append(bNode)
            buildingNodes.append((b, bNode))

            // Roof
            let roof = SCNBox(width: bw + CGFloat(0.3), height: CGFloat(0.3), length: bd + CGFloat(0.3), chamferRadius: CGFloat(0))
            roof.firstMaterial?.diffuse.contents = NSColor(red:0.4,green:0.15,blue:0.1,alpha:1)
            let roofNode = SCNNode(geometry: roof)
            roofNode.position = SCNVector3(CGFloat(b.gridX) + bw/CGFloat(2), bh + CGFloat(0.15), CGFloat(b.gridZ) + bd/CGFloat(2))
            scene.rootNode.addChildNode(roofNode); villageNodes.append(roofNode)

            // Label
            let textGeo = SCNText(string: b.name, extrusionDepth: CGFloat(0.05))
            textGeo.font = NSFont(name: "Menlo-Bold", size: 0.3)
            textGeo.firstMaterial?.diffuse.contents = NSColor.white
            let textNode = SCNNode(geometry: textGeo)
            textNode.scale = SCNVector3(CGFloat(0.8), CGFloat(0.8), CGFloat(0.8))
            let (mn, mx) = textNode.boundingBox
            let tw = CGFloat(mx.x - mn.x) * CGFloat(0.8)
            textNode.position = SCNVector3(CGFloat(b.gridX) + bw/CGFloat(2) - tw/CGFloat(2), bh + CGFloat(0.5), CGFloat(b.gridZ) + bd/CGFloat(2))
            scene.rootNode.addChildNode(textNode); villageNodes.append(textNode)
        }

        // NPCs
        for npc in loc.npcs {
            let npcNode = NPCModelBuilder.buildNPC(race: npc.race, name: npc.name)
            let startPos = npc.patrolPath.first ?? (8, 8)
            npcNode.position = SCNVector3(CGFloat(startPos.0), CGFloat(0), CGFloat(startPos.1))
            scene.rootNode.addChildNode(npcNode); villageNodes.append(npcNode)
            npcNodes.append((npc, npcNode))

            // Name label
            let nameGeo = SCNText(string: npc.name, extrusionDepth: CGFloat(0.02))
            nameGeo.font = NSFont(name: "Menlo", size: 0.2)
            nameGeo.firstMaterial?.diffuse.contents = NSColor.yellow
            let nameNode = SCNNode(geometry: nameGeo)
            let (nmn, nmx) = nameNode.boundingBox
            let nw = CGFloat(nmx.x - nmn.x)
            nameNode.position = SCNVector3(-nw/CGFloat(2), CGFloat(0.85), CGFloat(0))
            npcNode.addChildNode(nameNode)

            // Simple patrol
            if npc.patrolPath.count > 1 {
                var actions: [SCNAction] = []
                for pos in npc.patrolPath {
                    actions.append(SCNAction.move(to: SCNVector3(CGFloat(pos.0), CGFloat(0), CGFloat(pos.1)), duration: 3.0))
                }
                npcNode.runAction(SCNAction.repeatForever(SCNAction.sequence(actions)))
            }
        }

        // Player
        let playerNode = NPCModelBuilder.buildPlayer(cls: player.cls)
        player.gridX = 8; player.gridZ = 14
        playerNode.position = SCNVector3(CGFloat(player.gridX), CGFloat(0), CGFloat(player.gridZ))
        scene.rootNode.addChildNode(playerNode); player.node = playerNode

        // Camera
        cameraNode.position = SCNVector3(CGFloat(8), CGFloat(12), CGFloat(20))
        cameraNode.look(at: SCNVector3(CGFloat(8), CGFloat(0), CGFloat(8)))

        updateHUD()
    }

    // MARK: - World Map
    func showWorldMap() {
        state = .worldMap
        clearWorldMap()

        let bg = SKShapeNode(rect: CGRect(x: 0, y: 60, width: 900, height: 600))
        bg.fillColor = NSColor(red: 0.05, green: 0.08, blue: 0.05, alpha: 0.95)
        bg.strokeColor = NSColor(red: 0.3, green: 0.5, blue: 0.3, alpha: 0.8)
        bg.name = "worldmap"; overlay.addChild(bg); worldMapNodes.append(bg)

        let mapTitle = SKLabelNode(fontNamed: "Menlo-Bold"); mapTitle.fontSize = 18
        mapTitle.fontColor = NSColor(red: 1, green: 0.85, blue: 0.3, alpha: 1)
        mapTitle.text = "WORLD MAP"; mapTitle.position = CGPoint(x: 450, y: 630)
        overlay.addChild(mapTitle); worldMapNodes.append(mapTitle)

        // Draw connections first
        for (id, loc) in locations {
            for conn in loc.connections {
                if let other = locations[conn], id.rawValue < conn.rawValue {
                    let path = CGMutablePath()
                    path.move(to: CGPoint(x: loc.mapX, y: loc.mapY))
                    path.addLine(to: CGPoint(x: other.mapX, y: other.mapY))
                    let line = SKShapeNode(path: path)
                    line.strokeColor = NSColor(white: 0.4, alpha: 0.8); line.lineWidth = 2
                    overlay.addChild(line); worldMapNodes.append(line)
                }
            }
        }

        // Draw location nodes
        for (id, loc) in locations {
            let isCurrent = id == currentLocation
            let circle = SKShapeNode(circleOfRadius: isCurrent ? 28 : 22)
            circle.position = CGPoint(x: loc.mapX, y: loc.mapY)
            circle.fillColor = isCurrent ? NSColor(red: 0.3, green: 0.5, blue: 0.3, alpha: 1) : NSColor(red: 0.2, green: 0.2, blue: 0.3, alpha: 1)
            circle.strokeColor = isCurrent ? NSColor.green : NSColor(white: 0.6, alpha: 1)
            circle.lineWidth = isCurrent ? 3 : 1.5
            circle.name = "maploc_\(id.rawValue)"; overlay.addChild(circle); worldMapNodes.append(circle)

            let lbl = SKLabelNode(fontNamed: "Menlo-Bold"); lbl.fontSize = 11
            lbl.fontColor = NSColor.white; lbl.text = loc.name
            lbl.position = CGPoint(x: loc.mapX, y: loc.mapY - 38)
            lbl.name = "maploc_\(id.rawValue)"; overlay.addChild(lbl); worldMapNodes.append(lbl)
        }

        updateHUD()
    }

    func clearWorldMap() {
        for n in worldMapNodes { n.removeFromParent() }; worldMapNodes.removeAll()
    }

    func travelTo(_ dest: LocationID) {
        if dest == currentLocation { addNarration("You are already here."); return }
        guard let loc = locations[currentLocation], loc.connections.contains(dest) else {
            addNarration("You cannot travel there directly."); return
        }
        clearWorldMap()
        state = .traveling
        travelDestination = dest
        player.day += 1
        addNarration("Traveling to \(dest.rawValue)... (Day \(player.day))")

        // 30% random encounter
        if Int.random(in: 0..<10) < 3 {
            addNarration("Ambush on the road!")
            startRandomEncounter()
        } else {
            addNarration("You arrive safely at \(dest.rawValue).")
            currentLocation = dest
            // Campaign chapter narration
            checkCampaignProgression()
            enterVillage(dest)
        }
    }

    func startRandomEncounter() {
        // Set up a simple combat on a small grid
        clearScene()
        state = .combat; inCombat = true
        let size = 10
        dungeonGen = DungeonGenerator(width: size, height: size)
        dungeonGen.grid = Array(repeating: Array(repeating: 1, count: size), count: size)
        player.gridX = 2; player.gridZ = 5; player.movementLeft = player.speed
        buildDungeonScene()
        let roadEnemies: [MonsterType] = [.goblin, .giantRat, .orcBerserker]
        let enemyCount = 2 + Int.random(in: 0...2)
        for _ in 0..<enemyCount {
            let et = roadEnemies[Int.random(in: 0..<roadEnemies.count)]
            let mx = Int.random(in: 6..<9); let mz = Int.random(in: 3..<7)
            let m = MonsterCharacter(type: et, gridX: mx, gridZ: mz)
            let mn = NPCModelBuilder.buildMonster(type: et)
            mn.position = SCNVector3(CGFloat(mx), CGFloat(0.05), CGFloat(mz))
            scene.rootNode.addChildNode(mn); dungeonTileNodes.append(mn)
            m.node = mn; monsters.append(m)
        }
        addNarration("Enemies block the road!")
        turnIndicatorLabel.text = "YOUR TURN"; turnIndicatorLabel.isHidden = false
        showAbilityButtons()
        updateHUD()
    }

    func checkCampaignProgression() {
        // Simple chapter advancement based on visiting locations
        if player.campaignChapter == 1 && currentLocation == .oakvale { return }
        if player.campaignChapter == 1 { /* need to clear goblin caves first */ }
        if player.campaignChapter == 2 && currentLocation == .silverwood {
            addNarration(campaignChapters[1].intro)
            addNarration("Objective: \(campaignChapters[1].objective)")
        }
        if player.campaignChapter == 3 && currentLocation == .ironhold {
            addNarration(campaignChapters[2].intro)
            addNarration("Objective: \(campaignChapters[2].objective)")
        }
        if player.campaignChapter == 4 && currentLocation == .marshfen {
            addNarration(campaignChapters[3].intro)
            addNarration("Objective: \(campaignChapters[3].objective)")
        }
    }

    // MARK: - Dungeon
    func enterDungeon(_ dungeonName: String) {
        guard let info = dungeonData[dungeonName] else { addNarration("Unknown dungeon."); return }
        currentDungeon = dungeonName; currentFloor = 1; maxFloors = info.floors
        addNarration("Entering \(dungeonName) - Floor \(currentFloor)")
        generateDungeonFloor(info: info)
    }

    func generateDungeonFloor(info: DungeonInfo) {
        clearScene()
        state = .dungeon; inCombat = false
        dungeonGen = DungeonGenerator()
        dungeonGen.generate(floor: currentFloor)
        player.gridX = dungeonGen.playerStart.0; player.gridZ = dungeonGen.playerStart.1
        player.movementLeft = player.speed

        // Spawn monsters
        var types = info.enemyTypes
        if currentFloor == maxFloors, let boss = info.bossType { types.append(boss) }
        monsters = dungeonGen.spawnMonsters(types: types, floor: currentFloor)
        if currentFloor == maxFloors, let boss = info.bossType {
            // Ensure boss is placed
            if let lastRoom = dungeonGen.rooms.last {
                let bx = lastRoom.x + lastRoom.w/2 + 1; let bz = lastRoom.y + lastRoom.h/2
                let bossMonster = MonsterCharacter(type: boss, gridX: bx, gridZ: bz)
                monsters.append(bossMonster)
            }
        }

        buildDungeonScene()

        // Update explore quests
        for i in 0..<player.activeQuests.count {
            if player.activeQuests[i].type == .explore && player.activeQuests[i].targetDungeon == currentDungeon {
                player.activeQuests[i].progress = currentFloor
                if player.activeQuests[i].progress >= player.activeQuests[i].targetCount {
                    player.activeQuests[i].completed = true
                    addNarration("Quest complete: \(player.activeQuests[i].name)!")
                }
            }
        }

        addNarration("\(currentDungeon) - Floor \(currentFloor)/\(maxFloors)")
        updateHUD()
    }

    func buildDungeonScene() {
        // Ground
        let floorPlane = SCNFloor()
        floorPlane.firstMaterial?.diffuse.contents = NSColor(red: 0.15, green: 0.12, blue: 0.1, alpha: 1)
        let floorNode = SCNNode(geometry: floorPlane)
        scene.rootNode.addChildNode(floorNode); dungeonTileNodes.append(floorNode)

        for z in 0..<dungeonGen.height {
            for x in 0..<dungeonGen.width {
                let tile = dungeonGen.grid[z][x]
                if tile == 0 {
                    // Wall
                    let wall = SCNBox(width: CGFloat(1), height: CGFloat(1.5), length: CGFloat(1), chamferRadius: CGFloat(0))
                    wall.firstMaterial?.diffuse.contents = NSColor(red: 0.25, green: 0.2, blue: 0.18, alpha: 1)
                    let wn = SCNNode(geometry: wall)
                    wn.position = SCNVector3(CGFloat(x), CGFloat(0.75), CGFloat(z))
                    scene.rootNode.addChildNode(wn); dungeonTileNodes.append(wn)
                } else if tile == 3 {
                    // Stairs
                    let stairs = SCNBox(width: CGFloat(0.8), height: CGFloat(0.1), length: CGFloat(0.8), chamferRadius: CGFloat(0))
                    stairs.firstMaterial?.diffuse.contents = NSColor(red: 0.8, green: 0.7, blue: 0.2, alpha: 1)
                    stairs.firstMaterial?.emission.contents = NSColor(red: 0.3, green: 0.3, blue: 0.1, alpha: 1)
                    let sn = SCNNode(geometry: stairs)
                    sn.position = SCNVector3(CGFloat(x), CGFloat(0.05), CGFloat(z))
                    scene.rootNode.addChildNode(sn); dungeonTileNodes.append(sn)
                } else if tile == 4 {
                    // Chest
                    let chest = SCNBox(width: CGFloat(0.4), height: CGFloat(0.3), length: CGFloat(0.3), chamferRadius: CGFloat(0.02))
                    chest.firstMaterial?.diffuse.contents = NSColor(red: 0.7, green: 0.5, blue: 0.1, alpha: 1)
                    let cn = SCNNode(geometry: chest)
                    cn.position = SCNVector3(CGFloat(x), CGFloat(0.15), CGFloat(z))
                    scene.rootNode.addChildNode(cn); dungeonTileNodes.append(cn)
                } else if tile == 5 {
                    // Trap (subtle)
                    let trap = SCNBox(width: CGFloat(0.6), height: CGFloat(0.02), length: CGFloat(0.6), chamferRadius: CGFloat(0))
                    trap.firstMaterial?.diffuse.contents = NSColor(red: 0.2, green: 0.15, blue: 0.12, alpha: 1)
                    let tpn = SCNNode(geometry: trap)
                    tpn.position = SCNVector3(CGFloat(x), CGFloat(0.01), CGFloat(z))
                    scene.rootNode.addChildNode(tpn); dungeonTileNodes.append(tpn)
                }
            }
        }

        // Player
        let playerNode = NPCModelBuilder.buildPlayer(cls: player.cls)
        playerNode.position = SCNVector3(CGFloat(player.gridX), CGFloat(0.05), CGFloat(player.gridZ))
        scene.rootNode.addChildNode(playerNode); player.node = playerNode; dungeonTileNodes.append(playerNode)

        // Monsters
        for m in monsters {
            let mn = NPCModelBuilder.buildMonster(type: m.type)
            mn.position = SCNVector3(CGFloat(m.gridX), CGFloat(0.05), CGFloat(m.gridZ))
            if !m.revealed { mn.isHidden = true }
            scene.rootNode.addChildNode(mn); m.node = mn; dungeonTileNodes.append(mn)
        }

        // Camera
        cameraNode.position = SCNVector3(CGFloat(player.gridX), CGFloat(15), CGFloat(player.gridZ) + CGFloat(10))
        cameraNode.look(at: SCNVector3(CGFloat(player.gridX), CGFloat(0), CGFloat(player.gridZ)))
    }

    func handleDungeonTileStep() {
        let tile = dungeonGen.grid[player.gridZ][player.gridX]
        if tile == 3 {
            // Stairs
            if currentFloor < maxFloors {
                currentFloor += 1
                addNarration("Descending to floor \(currentFloor)...")
                player.resetAbilityUses()
                if player.cls == .wizard { player.mana = min(player.maxMana, player.mana + 2) }
                if let info = dungeonData[currentDungeon] {
                    generateDungeonFloor(info: info)
                }
            } else {
                addNarration("You have cleared \(currentDungeon)!")
                advanceCampaignAfterDungeon()
                enterVillage(currentLocation)
            }
        } else if tile == 4 {
            // Chest loot
            dungeonGen.grid[player.gridZ][player.gridX] = 1
            let goldFound = 10 + rollD(20) * currentFloor
            player.gold += goldFound
            addNarration("You found a chest with \(goldFound) gold!")
            if Int.random(in: 0..<3) == 0 {
                let potion = Item(name: "Healing Potion", type: .potion, value: 0, cost: 0)
                if player.inventory.count < 10 { player.inventory.append(potion); addNarration("Found a Healing Potion!") }
            }
            updateHUD()
        } else if tile == 5 {
            // Trap
            dungeonGen.grid[player.gridZ][player.gridX] = 1
            let save = rollD(20) + abilityMod(player.abilities.dex)
            if save < 13 {
                let dmg = rollDice(count: 2, sides: 6).total
                player.hp -= dmg
                addNarration("You triggered a trap! \(dmg) damage! (DEX save: \(save))")
                if player.hp <= 0 { handlePlayerDeath() }
            } else {
                addNarration("You spotted a trap and avoided it! (DEX save: \(save))")
            }
            updateHUD()
        }
    }

    func advanceCampaignAfterDungeon() {
        if currentDungeon == "Goblin Caves" && player.campaignChapter == 1 {
            player.campaignChapter = 2
            addNarration("Chapter 1 complete! The Goblin Caves are cleared.")
            addNarration(campaignChapters[1].intro)
        } else if currentDungeon == "Ironhold Mine" && player.campaignChapter == 3 {
            player.campaignChapter = 4
            addNarration("Chapter 3 complete! The Mine is safe again.")
        } else if currentDungeon == "Undead Crypt" && player.campaignChapter == 4 {
            player.campaignChapter = 5
            addNarration("Chapter 4 complete! The source of evil is revealed.")
        } else if currentDungeon == "Dragon's Lair" && player.campaignChapter == 5 {
            addNarration("VICTORY! You have defeated the Young Dragon and saved the realm!")
            showVictory()
            return
        }
    }

    func showVictory() {
        state = .gameOver
        let bg = SKShapeNode(rect: CGRect(x: 200, y: 200, width: 680, height: 320), cornerRadius: 12)
        bg.fillColor = NSColor(red: 0.05, green: 0.1, blue: 0.05, alpha: 0.95)
        bg.strokeColor = NSColor(red: 0.6, green: 0.8, blue: 0.3, alpha: 1)
        bg.lineWidth = 2; bg.name = "victory"; overlay.addChild(bg); menuNodes.append(bg)
        let lbl = SKLabelNode(fontNamed: "Menlo-Bold"); lbl.fontSize = 24
        lbl.fontColor = NSColor(red: 1, green: 0.85, blue: 0.3, alpha: 1)
        lbl.text = "VICTORY!"; lbl.position = CGPoint(x: 540, y: 420); lbl.name = "victory"
        overlay.addChild(lbl); menuNodes.append(lbl)
        let sub = SKLabelNode(fontNamed: "Menlo"); sub.fontSize = 14
        sub.fontColor = NSColor(white: 0.8, alpha: 1)
        sub.text = "The realm is saved! Click to play again."; sub.position = CGPoint(x: 540, y: 380)
        sub.name = "victory"; overlay.addChild(sub); menuNodes.append(sub)
    }

    func handlePlayerDeath() {
        state = .gameOver
        addNarration("You have fallen...")
        let bg = SKShapeNode(rect: CGRect(x: 200, y: 200, width: 680, height: 320), cornerRadius: 12)
        bg.fillColor = NSColor(red: 0.1, green: 0.02, blue: 0.02, alpha: 0.95)
        bg.strokeColor = NSColor.red; bg.lineWidth = 2; bg.name = "gameover"
        overlay.addChild(bg); menuNodes.append(bg)
        let lbl = SKLabelNode(fontNamed: "Menlo-Bold"); lbl.fontSize = 24
        lbl.fontColor = NSColor.red; lbl.text = "GAME OVER"
        lbl.position = CGPoint(x: 540, y: 400); lbl.name = "gameover"
        overlay.addChild(lbl); menuNodes.append(lbl)
        let sub = SKLabelNode(fontNamed: "Menlo"); sub.fontSize = 14
        sub.fontColor = NSColor(white: 0.7, alpha: 1)
        sub.text = "Click to restart"; sub.position = CGPoint(x: 540, y: 360); sub.name = "gameover"
        overlay.addChild(sub); menuNodes.append(sub)
    }

    // MARK: - Dialogue System
    func showDialogue(_ npc: NPCData) {
        state = .dialogue
        currentDialogueNPC = npc
        guard let line = npc.dialogues.first else { return }
        currentDialogueResponses = line.responses

        dialogueBg.isHidden = false; dialogueNameLabel.isHidden = false; dialogueTextLabel.isHidden = false
        dialogueNameLabel.text = "\(npc.name) (\(npc.race))"
        dialogueTextLabel.text = line.text

        // Clear old buttons
        for b in dialogueButtons { b.removeFromParent() }; dialogueButtons.removeAll()
        for l in dialogueButtonLabels { l.removeFromParent() }; dialogueButtonLabels.removeAll()

        for (i, resp) in line.responses.enumerated() {
            let y = CGFloat(350 - i * 50)
            let btn = SKShapeNode(rect: CGRect(x: 240, y: y - 15, width: 600, height: 40), cornerRadius: 6)
            btn.fillColor = NSColor(red: 0.15, green: 0.1, blue: 0.2, alpha: 0.9)
            btn.strokeColor = NSColor(red: 0.5, green: 0.4, blue: 0.7, alpha: 0.7)
            btn.name = "dlg_\(i)"; overlay.addChild(btn); dialogueButtons.append(btn)
            let lbl = SKLabelNode(fontNamed: "Menlo"); lbl.fontSize = 12
            lbl.fontColor = NSColor(white: 0.9, alpha: 1); lbl.text = resp.label
            lbl.position = CGPoint(x: 540, y: y - 3); lbl.name = "dlg_\(i)"
            overlay.addChild(lbl); dialogueButtonLabels.append(lbl)
        }
    }

    func hideDialogue() {
        dialogueBg.isHidden = true; dialogueNameLabel.isHidden = true; dialogueTextLabel.isHidden = true
        for b in dialogueButtons { b.removeFromParent() }; dialogueButtons.removeAll()
        for l in dialogueButtonLabels { l.removeFromParent() }; dialogueButtonLabels.removeAll()
        currentDialogueNPC = nil
    }

    func handleDialogueResponse(_ index: Int) {
        guard index < currentDialogueResponses.count else { return }
        let action = currentDialogueResponses[index].action
        hideDialogue()

        switch action {
        case "close":
            state = .village; updateHUD()
        case "quest_board":
            showQuestBoard()
        case "shop_general":
            showShop(items: generalShopItems, type: "General Shop")
        case "shop_herbalist":
            showShop(items: herbalistItems, type: "Herbalist")
        case "shop_blacksmith":
            showBlacksmith()
        case "info_rumor":
            let rumors = [
                "I hear the Goblin Caves hold treasure on the third floor.",
                "Beware the Undead Crypt - wraiths drain your very life force.",
                "The dwarves lost their mine to orcs and spiders.",
                "They say a young dragon nests in the Wilds.",
                "Silverwood's corruption comes from deep underground.",
                "A mimic lurks somewhere, disguised as a treasure chest.",
            ]
            addNarration("Rumor: \(rumors[Int.random(in: 0..<rumors.count)])")
            state = .village; updateHUD()
        case "info_oakvale":
            addNarration("Oakvale is a peaceful human village with an inn, guild, and shops.")
            state = .village; updateHUD()
        case "info_silverwood":
            addNarration("The elves of Silverwood are ancient and wise, but troubled by dark forces.")
            state = .village; updateHUD()
        case "info_mine":
            addNarration("The Ironhold Mine, once rich with ore, is now overrun with monsters.")
            state = .village; updateHUD()
        case "info_swamp":
            addNarration("The swamp crypt entrance lies to the south. Spiders and worse lurk within.")
            state = .village; updateHUD()
        case "info_rank":
            addNarration("Guild Rank: \(player.guildRank.rawValue) (\(player.questsCompleted) quests completed)")
            state = .village; updateHUD()
        case "buff_ale":
            if player.gold >= 5 {
                player.gold -= 5
                player.effects.append(ActiveEffect(effect: .blessed, turnsRemaining: 10, value: 2))
                addNarration("You drink a fine dwarven ale! (+2 attack for 10 turns)")
            } else { addNarration("Not enough gold!") }
            state = .village; updateHUD()
        case "quest_campaign1":
            if player.campaignChapter == 1 {
                addNarration("Mayor Aldric: Clear the Goblin Caves! Reach floor 3.")
                let q = Quest(id:"campaign1",name:"Clear Goblin Caves",description:"Reach floor 3 of Goblin Caves for Mayor Aldric",type:.explore,targetCount:3,progress:0,rewardXP:200,rewardGold:100,requiredFloor:3,completed:false,targetMonster:nil,targetDungeon:"Goblin Caves")
                if !player.activeQuests.contains(where:{$0.id=="campaign1"}) { player.activeQuests.append(q) }
            }
            state = .village; updateHUD()
        case "quest_campaign2":
            if player.campaignChapter == 2 {
                addNarration("Elder Aelindra: Investigate the Undead Crypt. The corruption spreads from there.")
                player.campaignChapter = 3
            }
            state = .village; updateHUD()
        case "quest_campaign3":
            if player.campaignChapter == 3 {
                addNarration("Forgemaster Durin: Clear the mine of these foul beasts!")
            }
            state = .village; updateHUD()
        case "quest_campaign4":
            if player.campaignChapter == 4 {
                addNarration("Witch Morga: The crypt... that is where you must go. Heh heh...")
            }
            state = .village; updateHUD()
        default:
            state = .village; updateHUD()
        }
    }

    // MARK: - Quest Board
    func showQuestBoard() {
        state = .questBoard
        clearQuestBoard()

        let bg = SKShapeNode(rect: CGRect(x: 100, y: 80, width: 700, height: 560), cornerRadius: 8)
        bg.fillColor = NSColor(red: 0.08, green: 0.06, blue: 0.04, alpha: 0.95)
        bg.strokeColor = NSColor(red: 0.6, green: 0.5, blue: 0.2, alpha: 1)
        bg.lineWidth = 2; overlay.addChild(bg); questBoardNodes.append(bg)

        let title = SKLabelNode(fontNamed: "Menlo-Bold"); title.fontSize = 18
        title.fontColor = NSColor(red: 1, green: 0.85, blue: 0.3, alpha: 1)
        title.text = "QUEST BOARD"; title.position = CGPoint(x: 450, y: 610)
        overlay.addChild(title); questBoardNodes.append(title)

        // Populate available quests (random selection of 5-6 from pool)
        if availableQuests.isEmpty {
            let pool = questPool.shuffled()
            availableQuests = Array(pool.prefix(6))
        }

        // Show active quests first
        var y = CGFloat(575)
        if !player.activeQuests.isEmpty {
            let actTitle = SKLabelNode(fontNamed: "Menlo-Bold"); actTitle.fontSize = 13
            actTitle.fontColor = NSColor.green; actTitle.text = "ACTIVE QUESTS:"
            actTitle.position = CGPoint(x: 130, y: y); actTitle.horizontalAlignmentMode = .left
            overlay.addChild(actTitle); questBoardNodes.append(actTitle); y -= 22
            for q in player.activeQuests {
                let ql = SKLabelNode(fontNamed: "Menlo"); ql.fontSize = 11
                let status = q.completed ? "[COMPLETE]" : "[\(q.progress)/\(q.targetCount)]"
                ql.fontColor = q.completed ? NSColor.green : NSColor(white: 0.8, alpha: 1)
                ql.text = "\(q.name) \(status) - \(q.rewardXP)XP \(q.rewardGold)g"
                ql.position = CGPoint(x: 140, y: y); ql.horizontalAlignmentMode = .left
                overlay.addChild(ql); questBoardNodes.append(ql); y -= 20
                if q.completed {
                    let turnIn = SKShapeNode(rect: CGRect(x: 600, y: y + 8, width: 120, height: 22), cornerRadius: 4)
                    turnIn.fillColor = NSColor(red: 0.2, green: 0.5, blue: 0.2, alpha: 0.9)
                    turnIn.strokeColor = NSColor.green; turnIn.name = "turnin_\(q.id)"
                    overlay.addChild(turnIn); questBoardNodes.append(turnIn)
                    let tl = SKLabelNode(fontNamed: "Menlo"); tl.fontSize = 11
                    tl.fontColor = NSColor.white; tl.text = "TURN IN"; tl.position = CGPoint(x: 660, y: y + 12)
                    tl.name = "turnin_\(q.id)"; overlay.addChild(tl); questBoardNodes.append(tl)
                }
            }
            y -= 15
        }

        // Available quests
        let avTitle = SKLabelNode(fontNamed: "Menlo-Bold"); avTitle.fontSize = 13
        avTitle.fontColor = NSColor(red: 0.8, green: 0.7, blue: 0.3, alpha: 1); avTitle.text = "AVAILABLE:"
        avTitle.position = CGPoint(x: 130, y: y); avTitle.horizontalAlignmentMode = .left
        overlay.addChild(avTitle); questBoardNodes.append(avTitle); y -= 22

        for (i, q) in availableQuests.enumerated() {
            if player.activeQuests.contains(where: { $0.id == q.id }) { continue }
            if player.completedQuests.contains(where: { $0.id == q.id }) { continue }
            let ql = SKLabelNode(fontNamed: "Menlo"); ql.fontSize = 11
            ql.fontColor = NSColor(white: 0.75, alpha: 1)
            ql.text = "\(q.name): \(q.description) (\(q.rewardXP)XP, \(q.rewardGold)g)"
            ql.position = CGPoint(x: 140, y: y); ql.horizontalAlignmentMode = .left
            overlay.addChild(ql); questBoardNodes.append(ql)

            let accept = SKShapeNode(rect: CGRect(x: 600, y: y - 5, width: 120, height: 22), cornerRadius: 4)
            accept.fillColor = NSColor(red: 0.2, green: 0.3, blue: 0.5, alpha: 0.9)
            accept.strokeColor = NSColor(red: 0.4, green: 0.5, blue: 0.8, alpha: 1); accept.name = "accept_\(i)"
            overlay.addChild(accept); questBoardNodes.append(accept)
            let al = SKLabelNode(fontNamed: "Menlo"); al.fontSize = 11
            al.fontColor = NSColor.white; al.text = "ACCEPT"; al.position = CGPoint(x: 660, y: y - 1)
            al.name = "accept_\(i)"; overlay.addChild(al); questBoardNodes.append(al)
            y -= 28
        }

        // Close button
        let closeBg = SKShapeNode(rect: CGRect(x: 380, y: 100, width: 140, height: 35), cornerRadius: 6)
        closeBg.fillColor = NSColor(red: 0.3, green: 0.15, blue: 0.1, alpha: 0.9)
        closeBg.strokeColor = NSColor(red: 0.6, green: 0.3, blue: 0.2, alpha: 1)
        closeBg.name = "close_quest"; overlay.addChild(closeBg); questBoardNodes.append(closeBg)
        let cl = SKLabelNode(fontNamed: "Menlo"); cl.fontSize = 13
        cl.fontColor = NSColor.white; cl.text = "CLOSE"; cl.position = CGPoint(x: 450, y: 110)
        cl.name = "close_quest"; overlay.addChild(cl); questBoardNodes.append(cl)
    }

    func clearQuestBoard() {
        for n in questBoardNodes { n.removeFromParent() }; questBoardNodes.removeAll()
    }

    func acceptQuest(_ index: Int) {
        guard index < availableQuests.count else { return }
        let q = availableQuests[index]
        if player.activeQuests.count >= 5 { addNarration("Quest log full! (max 5)"); return }
        if player.activeQuests.contains(where: { $0.id == q.id }) { addNarration("Already tracking this quest."); return }
        player.activeQuests.append(q)
        addNarration("Accepted quest: \(q.name)")
        clearQuestBoard(); showQuestBoard()
    }

    func turnInQuest(_ id: String) {
        guard let idx = player.activeQuests.firstIndex(where: { $0.id == id && $0.completed }) else { return }
        let q = player.activeQuests[idx]
        player.gold += q.rewardGold
        let leveled = player.gainXP(q.rewardXP)
        addNarration("Quest complete! +\(q.rewardXP) XP, +\(q.rewardGold) gold")
        if leveled { addNarration("LEVEL UP! Now level \(player.level)!") }
        player.completedQuests.append(q)
        player.activeQuests.remove(at: idx)
        player.questsCompleted += 1
        // Guild rank
        if player.questsCompleted >= 9 { player.guildRank = .platinum }
        else if player.questsCompleted >= 6 { player.guildRank = .gold }
        else if player.questsCompleted >= 3 { player.guildRank = .silver }
        clearQuestBoard(); showQuestBoard()
    }

    // MARK: - Shop
    func showShop(items: [Item], type: String) {
        state = .shop; shopItems = items; shopType = type
        clearShop()

        let bg = SKShapeNode(rect: CGRect(x: 150, y: 120, width: 600, height: 480), cornerRadius: 8)
        bg.fillColor = NSColor(red: 0.06, green: 0.05, blue: 0.08, alpha: 0.95)
        bg.strokeColor = NSColor(red: 0.5, green: 0.4, blue: 0.2, alpha: 1)
        bg.lineWidth = 2; overlay.addChild(bg); shopNodes.append(bg)

        let title = SKLabelNode(fontNamed: "Menlo-Bold"); title.fontSize = 18
        title.fontColor = NSColor(red: 1, green: 0.85, blue: 0.3, alpha: 1)
        title.text = type.uppercased(); title.position = CGPoint(x: 450, y: 570)
        overlay.addChild(title); shopNodes.append(title)

        let goldLbl = SKLabelNode(fontNamed: "Menlo"); goldLbl.fontSize = 13
        goldLbl.fontColor = NSColor(red: 1, green: 0.9, blue: 0.3, alpha: 1)
        goldLbl.text = "Your gold: \(player.gold)"; goldLbl.position = CGPoint(x: 450, y: 545)
        overlay.addChild(goldLbl); shopNodes.append(goldLbl)

        for (i, item) in items.enumerated() {
            let y = CGFloat(500 - i * 50)
            let il = SKLabelNode(fontNamed: "Menlo"); il.fontSize = 12
            il.fontColor = NSColor(white: 0.85, alpha: 1)
            il.text = "\(item.name) - \(item.cost) gold"
            il.position = CGPoint(x: 200, y: y); il.horizontalAlignmentMode = .left
            overlay.addChild(il); shopNodes.append(il)

            let buy = SKShapeNode(rect: CGRect(x: 580, y: y - 8, width: 100, height: 28), cornerRadius: 4)
            buy.fillColor = NSColor(red: 0.2, green: 0.35, blue: 0.2, alpha: 0.9)
            buy.strokeColor = NSColor(red: 0.3, green: 0.6, blue: 0.3, alpha: 1); buy.name = "buy_\(i)"
            overlay.addChild(buy); shopNodes.append(buy)
            let bl = SKLabelNode(fontNamed: "Menlo"); bl.fontSize = 11
            bl.fontColor = NSColor.white; bl.text = "BUY"; bl.position = CGPoint(x: 630, y: y - 2); bl.name = "buy_\(i)"
            overlay.addChild(bl); shopNodes.append(bl)
        }

        // Close
        let closeBg = SKShapeNode(rect: CGRect(x: 380, y: 140, width: 140, height: 35), cornerRadius: 6)
        closeBg.fillColor = NSColor(red: 0.3, green: 0.15, blue: 0.1, alpha: 0.9)
        closeBg.strokeColor = NSColor(red: 0.6, green: 0.3, blue: 0.2, alpha: 1); closeBg.name = "close_shop"
        overlay.addChild(closeBg); shopNodes.append(closeBg)
        let cl = SKLabelNode(fontNamed: "Menlo"); cl.fontSize = 13
        cl.fontColor = NSColor.white; cl.text = "CLOSE"; cl.position = CGPoint(x: 450, y: 150); cl.name = "close_shop"
        overlay.addChild(cl); shopNodes.append(cl)
    }

    func showBlacksmith() {
        state = .shop; shopType = "Blacksmith"
        clearShop()
        var items: [Item] = []
        let weaponCost = 50 * (player.weaponBonus + 1)
        let armorCost = 75 * (player.armorBonus + 1)
        if player.weaponBonus < 3 { items.append(Item(name: "Weapon Upgrade (+\(player.weaponBonus+1))", type: .weaponUpgrade, value: 1, cost: weaponCost)) }
        if player.armorBonus < 2 { items.append(Item(name: "Armor Upgrade (+\(player.armorBonus+1))", type: .armorUpgrade, value: 1, cost: armorCost)) }
        shopItems = items
        showShop(items: items, type: "Blacksmith")
    }

    func clearShop() {
        for n in shopNodes { n.removeFromParent() }; shopNodes.removeAll()
    }

    func buyItem(_ index: Int) {
        guard index < shopItems.count else { return }
        let item = shopItems[index]
        if player.gold < item.cost { addNarration("Not enough gold!"); return }
        if item.type == .weaponUpgrade {
            player.gold -= item.cost; player.weaponBonus += 1
            addNarration("Weapon upgraded to +\(player.weaponBonus)!")
        } else if item.type == .armorUpgrade {
            player.gold -= item.cost; player.armorBonus += 1
            addNarration("Armor upgraded to +\(player.armorBonus)!")
        } else {
            if player.inventory.count >= 10 { addNarration("Inventory full! (max 10)"); return }
            player.gold -= item.cost; player.inventory.append(item)
            addNarration("Purchased \(item.name).")
        }
        clearShop()
        if shopType == "Blacksmith" { showBlacksmith() }
        else { showShop(items: shopItems, type: shopType) }
        updateHUD()
    }

    // MARK: - Rest (Inn)
    func restAtInn() {
        if player.gold < 10 { addNarration("You need 10 gold to rest at the inn."); return }
        player.gold -= 10; player.hp = player.maxHP; player.day += 1
        player.resetAbilityUses()
        if player.cls == .wizard { player.mana = player.maxMana }
        player.effects.removeAll()
        addNarration("You rest at the inn. HP fully restored. (Day \(player.day))")
        // Random rumor
        if Int.random(in: 0..<2) == 0 {
            let rumors = ["The dragon grows stronger each day...", "Treasure awaits the brave in the deepest dungeons.",
                          "The elves whisper of ancient magic in the forest.", "Dwarven ale gives strength before battle!"]
            addNarration("You overhear: \"\(rumors[Int.random(in: 0..<rumors.count)])\"")
        }
        updateHUD()
    }

    // MARK: - Inventory
    func showInventory() {
        state = .inventory
        clearInventory()

        let bg = SKShapeNode(rect: CGRect(x: 150, y: 100, width: 600, height: 520), cornerRadius: 8)
        bg.fillColor = NSColor(red: 0.06, green: 0.05, blue: 0.08, alpha: 0.95)
        bg.strokeColor = NSColor(red: 0.5, green: 0.4, blue: 0.6, alpha: 1)
        bg.lineWidth = 2; overlay.addChild(bg); inventoryNodes.append(bg)

        let title = SKLabelNode(fontNamed: "Menlo-Bold"); title.fontSize = 18
        title.fontColor = NSColor(red: 0.8, green: 0.7, blue: 1, alpha: 1)
        title.text = "INVENTORY (\(player.inventory.count)/10)"; title.position = CGPoint(x: 450, y: 590)
        overlay.addChild(title); inventoryNodes.append(title)

        // Stats summary
        let statsLbl = SKLabelNode(fontNamed: "Menlo"); statsLbl.fontSize = 11
        statsLbl.fontColor = NSColor(white: 0.7, alpha: 1)
        statsLbl.text = "STR:\(player.abilities.str) DEX:\(player.abilities.dex) CON:\(player.abilities.con) INT:\(player.abilities.intel) WIS:\(player.abilities.wis) CHA:\(player.abilities.cha)"
        statsLbl.position = CGPoint(x: 450, y: 565); overlay.addChild(statsLbl); inventoryNodes.append(statsLbl)

        let gearLbl = SKLabelNode(fontNamed: "Menlo"); gearLbl.fontSize = 11
        gearLbl.fontColor = NSColor(white: 0.7, alpha: 1)
        gearLbl.text = "Weapon: +\(player.weaponBonus)  Armor: +\(player.armorBonus)  AC: \(player.effectiveAC)"
        gearLbl.position = CGPoint(x: 450, y: 545); overlay.addChild(gearLbl); inventoryNodes.append(gearLbl)

        if player.inventory.isEmpty {
            let el = SKLabelNode(fontNamed: "Menlo"); el.fontSize = 12
            el.fontColor = NSColor(white: 0.5, alpha: 1); el.text = "Empty"
            el.position = CGPoint(x: 450, y: 480); overlay.addChild(el); inventoryNodes.append(el)
        } else {
            for (i, item) in player.inventory.enumerated() {
                let y = CGFloat(510 - i * 35)
                let il = SKLabelNode(fontNamed: "Menlo"); il.fontSize = 12
                il.fontColor = NSColor(white: 0.85, alpha: 1); il.text = item.name
                il.position = CGPoint(x: 200, y: y); il.horizontalAlignmentMode = .left
                overlay.addChild(il); inventoryNodes.append(il)

                let use = SKShapeNode(rect: CGRect(x: 560, y: y - 8, width: 80, height: 26), cornerRadius: 4)
                use.fillColor = NSColor(red: 0.2, green: 0.3, blue: 0.5, alpha: 0.9)
                use.strokeColor = NSColor(red: 0.4, green: 0.5, blue: 0.8, alpha: 1); use.name = "use_\(i)"
                overlay.addChild(use); inventoryNodes.append(use)
                let ul = SKLabelNode(fontNamed: "Menlo"); ul.fontSize = 11
                ul.fontColor = NSColor.white; ul.text = "USE"; ul.position = CGPoint(x: 600, y: y - 2); ul.name = "use_\(i)"
                overlay.addChild(ul); inventoryNodes.append(ul)

                let drop = SKShapeNode(rect: CGRect(x: 650, y: y - 8, width: 80, height: 26), cornerRadius: 4)
                drop.fillColor = NSColor(red: 0.4, green: 0.15, blue: 0.1, alpha: 0.9)
                drop.strokeColor = NSColor(red: 0.6, green: 0.3, blue: 0.2, alpha: 1); drop.name = "drop_\(i)"
                overlay.addChild(drop); inventoryNodes.append(drop)
                let dl = SKLabelNode(fontNamed: "Menlo"); dl.fontSize = 11
                dl.fontColor = NSColor.white; dl.text = "DROP"; dl.position = CGPoint(x: 690, y: y - 2); dl.name = "drop_\(i)"
                overlay.addChild(dl); inventoryNodes.append(dl)
            }
        }

        let closeBg = SKShapeNode(rect: CGRect(x: 380, y: 120, width: 140, height: 35), cornerRadius: 6)
        closeBg.fillColor = NSColor(red: 0.3, green: 0.15, blue: 0.1, alpha: 0.9)
        closeBg.strokeColor = NSColor(red: 0.6, green: 0.3, blue: 0.2, alpha: 1); closeBg.name = "close_inv"
        overlay.addChild(closeBg); inventoryNodes.append(closeBg)
        let cl = SKLabelNode(fontNamed: "Menlo"); cl.fontSize = 13
        cl.fontColor = NSColor.white; cl.text = "CLOSE"; cl.position = CGPoint(x: 450, y: 130); cl.name = "close_inv"
        overlay.addChild(cl); inventoryNodes.append(cl)
    }

    func clearInventory() {
        for n in inventoryNodes { n.removeFromParent() }; inventoryNodes.removeAll()
    }

    func useItem(_ index: Int) {
        guard index < player.inventory.count else { return }
        let item = player.inventory[index]
        switch item.type {
        case .potion:
            let heal = rollDice(count: 2, sides: 4).total + 2
            player.hp = min(player.maxHP, player.hp + heal)
            addNarration("Used Healing Potion. Healed \(heal) HP.")
        case .antidote:
            player.effects.removeAll(where: { $0.effect == .poisoned })
            addNarration("Used Antidote. Poison cured!")
        case .ration:
            let heal = rollD(4)
            player.hp = min(player.maxHP, player.hp + heal)
            addNarration("Ate rations. Healed \(heal) HP.")
        case .speedPotion:
            player.effects.append(ActiveEffect(effect: .blessed, turnsRemaining: 20, value: 0))
            player.speed += 2
            addNarration("Used Potion of Speed! +2 movement.")
        case .strengthPotion:
            player.effects.append(ActiveEffect(effect: .blessed, turnsRemaining: 20, value: 2))
            addNarration("Used Potion of Strength! +2 damage.")
        default: addNarration("Can't use that here.")
        }
        player.inventory.remove(at: index)
        clearInventory(); showInventory(); updateHUD()
    }

    // MARK: - Combat System
    func startCombat() {
        state = .combat; inCombat = true
        player.movementLeft = player.speed
        for i in 0..<monsters.count { monsters[i].hasActed = false }
        addNarration("Combat begins!")
        turnIndicatorLabel.text = "YOUR TURN"; turnIndicatorLabel.isHidden = false
        showAbilityButtons()
        updateHUD()
    }

    func showAbilityButtons() {
        for b in abilityButtons { b.removeFromParent() }; abilityButtons.removeAll()
        for l in abilityLabels { l.removeFromParent() }; abilityLabels.removeAll()
        let names: [String]
        switch player.cls {
        case .fighter: names = ["Power Strike","Shield Bash(\(player.abilityUses[2] ?? 0))","Second Wind(\(player.abilityUses[3] ?? 0))","Cleave(\(player.abilityUses[4] ?? 0))"]
        case .rogue: names = ["Backstab","Smoke Bomb(\(player.abilityUses[2] ?? 0))","Poison Blade(\(player.abilityUses[3] ?? 0))","Shadow Step(\(player.abilityUses[4] ?? 0))"]
        case .cleric: names = ["Holy Smite","Heal(\(player.abilityUses[2] ?? 0))","Turn Undead(\(player.abilityUses[3] ?? 0))","Divine Shield(\(player.abilityUses[4] ?? 0))"]
        case .wizard: names = ["Arcane Bolt","Fireball(m\(player.mana))","Ice Wall(m\(player.mana))","Lightning(m\(player.mana))"]
        case .warlock: names = ["Eldritch Blast","Hex(\(player.abilityUses[2] ?? 0))","Dark Pact(p\(player.pactPoints))","Summon(p\(player.pactPoints))"]
        }
        for (i, name) in names.enumerated() {
            let x = CGFloat(180 + i * 160)
            let btn = SKShapeNode(rect: CGRect(x: x - 65, y: 65, width: 130, height: 32), cornerRadius: 5)
            btn.fillColor = NSColor(red: 0.15, green: 0.12, blue: 0.25, alpha: 0.9)
            btn.strokeColor = NSColor(red: 0.5, green: 0.4, blue: 0.7, alpha: 0.8)
            btn.name = "ability_\(i+1)"; overlay.addChild(btn); abilityButtons.append(btn)
            let lbl = SKLabelNode(fontNamed: "Menlo"); lbl.fontSize = 10
            lbl.fontColor = NSColor(white: 0.9, alpha: 1); lbl.text = "[\(i+1)] \(name)"
            lbl.position = CGPoint(x: x, y: 75); lbl.name = "ability_\(i+1)"
            overlay.addChild(lbl); abilityLabels.append(lbl)
        }
        // End turn button
        let etBtn = SKShapeNode(rect: CGRect(x: 755, y: 65, width: 130, height: 32), cornerRadius: 5)
        etBtn.fillColor = NSColor(red: 0.25, green: 0.15, blue: 0.1, alpha: 0.9)
        etBtn.strokeColor = NSColor(red: 0.6, green: 0.3, blue: 0.2, alpha: 0.8); etBtn.name = "end_turn"
        overlay.addChild(etBtn); abilityButtons.append(etBtn)
        let etl = SKLabelNode(fontNamed: "Menlo"); etl.fontSize = 10
        etl.fontColor = NSColor(white: 0.9, alpha: 1); etl.text = "[Space] End Turn"
        etl.position = CGPoint(x: 820, y: 75); etl.name = "end_turn"
        overlay.addChild(etl); abilityLabels.append(etl)
    }

    func hideAbilityButtons() {
        for b in abilityButtons { b.removeFromParent() }; abilityButtons.removeAll()
        for l in abilityLabels { l.removeFromParent() }; abilityLabels.removeAll()
    }

    func useAbility(_ num: Int, targetMonster: MonsterCharacter? = nil) {
        guard state == .combat else { return }
        let target = targetMonster ?? nearestMonster()
        guard let t = target else { addNarration("No target in range."); return }

        let dist = abs(player.gridX - t.gridX) + abs(player.gridZ - t.gridZ)

        switch player.cls {
        case .fighter:
            switch num {
            case 1: // Power Strike
                if dist > 1 { addNarration("Too far for melee!"); return }
                let roll = rollD(20) + abilityMod(player.abilities.str) + player.weaponBonus
                let blessBonus = player.effects.contains(where:{$0.effect == .blessed}) ? 2 : 0
                if roll >= t.effectiveAC {
                    var dmg = rollD(10) + abilityMod(player.abilities.str) + player.weaponBonus + blessBonus + player.comboCount * 2
                    if roll - abilityMod(player.abilities.str) - player.weaponBonus == 20 { dmg *= 2; addNarration("CRITICAL HIT!"); screenShake() }
                    t.hp -= dmg; player.comboCount += 1
                    addNarration("Power Strike hits \(t.type.rawValue) for \(dmg)! (combo:\(player.comboCount))")
                    animateAttack(from: player.node, to: t.node)
                } else { addNarration("Power Strike misses! (rolled \(roll) vs AC \(t.effectiveAC))"); player.comboCount = 0 }
            case 2: // Shield Bash
                if dist > 1 { addNarration("Too far!"); return }
                guard let uses = player.abilityUses[2], uses > 0 else { addNarration("No uses left!"); return }
                player.abilityUses[2] = uses - 1
                let roll = rollD(20) + abilityMod(player.abilities.str)
                if roll >= t.effectiveAC {
                    let dmg = rollD(6) + abilityMod(player.abilities.str)
                    t.hp -= dmg; t.effects.append(ActiveEffect(effect: .stunned, turnsRemaining: 1, value: 0))
                    addNarration("Shield Bash stuns \(t.type.rawValue) for \(dmg)!")
                    animateAttack(from: player.node, to: t.node)
                } else { addNarration("Shield Bash misses!") }
            case 3: // Second Wind
                guard let uses = player.abilityUses[3], uses > 0 else { addNarration("No uses left!"); return }
                player.abilityUses[3] = uses - 1
                let heal = rollD(10) + player.level
                player.hp = min(player.maxHP, player.hp + heal)
                addNarration("Second Wind! Healed \(heal) HP.")
            case 4: // Cleave
                guard let uses = player.abilityUses[4], uses > 0 else { addNarration("No uses left!"); return }
                player.abilityUses[4] = uses - 1
                var hitAny = false
                for m in monsters where m.hp > 0 {
                    let md = abs(player.gridX - m.gridX) + abs(player.gridZ - m.gridZ)
                    if md <= 1 {
                        let dmg = rollD(8) + abilityMod(player.abilities.str) + player.weaponBonus
                        m.hp -= dmg; hitAny = true
                        addNarration("Cleave hits \(m.type.rawValue) for \(dmg)!")
                    }
                }
                if !hitAny { addNarration("No adjacent enemies to cleave!"); player.abilityUses[4] = (player.abilityUses[4] ?? 0) + 1 }
            default: break
            }
        case .rogue:
            switch num {
            case 1: // Backstab
                if dist > 1 { addNarration("Too far!"); return }
                let roll = rollD(20) + abilityMod(player.abilities.dex) + player.weaponBonus
                if roll >= t.effectiveAC {
                    var dmg = rollD(6) + abilityMod(player.abilities.dex) + player.weaponBonus
                    if !t.hasActed { dmg += rollDice(count: 3, sides: 6).total; addNarration("Sneak attack!") }
                    if roll - abilityMod(player.abilities.dex) - player.weaponBonus == 20 { dmg *= 2; addNarration("CRITICAL HIT!"); screenShake() }
                    t.hp -= dmg
                    addNarration("Backstab hits \(t.type.rawValue) for \(dmg)!")
                    animateAttack(from: player.node, to: t.node)
                } else { addNarration("Backstab misses!") }
            case 2: // Smoke Bomb
                guard let uses = player.abilityUses[2], uses > 0 else { addNarration("No uses left!"); return }
                player.abilityUses[2] = uses - 1
                addNarration("Smoke bomb! Next attack auto-crits.")
                player.comboCount = 99 // signal for auto-crit
            case 3: // Poison Blade
                guard let uses = player.abilityUses[3], uses > 0 else { addNarration("No uses left!"); return }
                player.abilityUses[3] = uses - 1
                addNarration("Your blade drips with poison! Next 3 attacks deal bonus poison damage.")
                player.comboCount = 3 // repurpose as poison counter
            case 4: // Shadow Step
                guard let uses = player.abilityUses[4], uses > 0 else { addNarration("No uses left!"); return }
                player.abilityUses[4] = uses - 1
                addNarration("Shadow Step! Click a tile within 4 squares to teleport.")
            default: break
            }
        case .cleric:
            switch num {
            case 1: // Holy Smite
                if dist > 1 { addNarration("Too far!"); return }
                let roll = rollD(20) + abilityMod(player.abilities.wis) + player.weaponBonus
                if roll >= t.effectiveAC {
                    var dmg = rollD(8) + abilityMod(player.abilities.wis) + player.weaponBonus
                    let isUndead = t.type == .skeletonWarrior || t.type == .skeletonArcher || t.type == .wraith
                    if isUndead { dmg += rollD(8); addNarration("Holy power sears the undead!") }
                    if roll - abilityMod(player.abilities.wis) - player.weaponBonus == 20 { dmg *= 2; addNarration("CRITICAL HIT!"); screenShake() }
                    t.hp -= dmg
                    addNarration("Holy Smite hits \(t.type.rawValue) for \(dmg)!")
                    animateAttack(from: player.node, to: t.node)
                } else { addNarration("Holy Smite misses!") }
            case 2: // Healing Word
                guard let uses = player.abilityUses[2], uses > 0 else { addNarration("No uses left!"); return }
                player.abilityUses[2] = uses - 1
                let heal = rollDice(count: 2, sides: 8).total + abilityMod(player.abilities.wis)
                player.hp = min(player.maxHP, player.hp + heal)
                addNarration("Healing Word restores \(heal) HP!")
            case 3: // Turn Undead
                guard let uses = player.abilityUses[3], uses > 0 else { addNarration("No uses left!"); return }
                player.abilityUses[3] = uses - 1
                var turned = 0
                for m in monsters where m.hp > 0 {
                    let md = abs(player.gridX - m.gridX) + abs(player.gridZ - m.gridZ)
                    let isUndead = m.type == .skeletonWarrior || m.type == .skeletonArcher || m.type == .wraith
                    if md <= 3 && isUndead { m.effects.append(ActiveEffect(effect: .stunned, turnsRemaining: 2, value: 0)); turned += 1 }
                }
                addNarration("Turn Undead! \(turned) undead flee in terror!")
            case 4: // Divine Shield
                guard let uses = player.abilityUses[4], uses > 0 else { addNarration("No uses left!"); return }
                player.abilityUses[4] = uses - 1
                player.effects.append(ActiveEffect(effect: .shielded, turnsRemaining: 3, value: 5))
                addNarration("Divine Shield! Damage reduced by 5 for 3 turns.")
            default: break
            }
        case .wizard:
            switch num {
            case 1: // Arcane Bolt
                if dist > 6 { addNarration("Out of range! (max 6)"); return }
                let roll = rollD(20) + abilityMod(player.abilities.intel)
                if roll >= t.effectiveAC {
                    var dmg = rollD(8) + abilityMod(player.abilities.intel)
                    if roll - abilityMod(player.abilities.intel) == 20 { dmg *= 2; addNarration("CRITICAL HIT!"); screenShake() }
                    t.hp -= dmg
                    addNarration("Arcane Bolt hits \(t.type.rawValue) for \(dmg)!")
                    animateAttack(from: player.node, to: t.node)
                } else { addNarration("Arcane Bolt misses!") }
            case 2: // Fireball
                if player.mana < 4 { addNarration("Not enough mana! (need 4)"); return }
                player.mana -= 4
                let dmg = rollDice(count: 6, sides: 6).total
                var hit = 0
                for m in monsters where m.hp > 0 {
                    let md = abs(t.gridX - m.gridX) + abs(t.gridZ - m.gridZ)
                    if md <= 2 {
                        let save = rollD(20) + 2 // DEX save
                        let actualDmg = save >= 14 ? dmg/2 : dmg
                        m.hp -= actualDmg; hit += 1
                    }
                }
                addNarration("Fireball! \(dmg) damage to \(hit) enemies!")
                animateFireball(at: t.node)
            case 3: // Ice Wall
                if player.mana < 3 { addNarration("Not enough mana! (need 3)"); return }
                player.mana -= 3
                addNarration("Ice Wall created! Blocking terrain for 3 turns.")
                // Place wall tiles in front of player
                let dx = t.gridX > player.gridX ? 1 : (t.gridX < player.gridX ? -1 : 0)
                let dz = t.gridZ > player.gridZ ? 1 : (t.gridZ < player.gridZ ? -1 : 0)
                for i in -1...1 {
                    let wx = player.gridX + dx * 2 + (dz == 0 ? i : 0)
                    let wz = player.gridZ + dz * 2 + (dx == 0 ? i : 0)
                    if wx >= 0 && wx < dungeonGen.width && wz >= 0 && wz < dungeonGen.height {
                        let ice = SCNBox(width: CGFloat(1), height: CGFloat(1.2), length: CGFloat(1), chamferRadius: CGFloat(0))
                        ice.firstMaterial?.diffuse.contents = NSColor(red: 0.6, green: 0.8, blue: 1, alpha: 0.6)
                        let in2 = SCNNode(geometry: ice)
                        in2.position = SCNVector3(CGFloat(wx), CGFloat(0.6), CGFloat(wz))
                        in2.opacity = CGFloat(0.6)
                        scene.rootNode.addChildNode(in2); dungeonTileNodes.append(in2)
                    }
                }
            case 4: // Lightning Bolt
                if player.mana < 5 { addNarration("Not enough mana! (need 5)"); return }
                player.mana -= 5
                let dmg = rollDice(count: 8, sides: 6).total
                let dx = t.gridX - player.gridX; let dz = t.gridZ - player.gridZ
                let maxD = max(abs(dx), abs(dz))
                let sdx = maxD > 0 ? dx / maxD : 0; let sdz = maxD > 0 ? dz / maxD : 0
                var hit = 0
                for step in 1...5 {
                    let cx = player.gridX + sdx * step; let cz = player.gridZ + sdz * step
                    for m in monsters where m.hp > 0 && m.gridX == cx && m.gridZ == cz {
                        m.hp -= dmg; hit += 1
                    }
                }
                addNarration("Lightning Bolt! \(dmg) damage, \(hit) hit!")
            default: break
            }
        case .warlock:
            switch num {
            case 1: // Eldritch Blast
                if dist > 6 { addNarration("Out of range!"); return }
                let roll = rollD(20) + abilityMod(player.abilities.cha)
                if roll >= t.effectiveAC {
                    var dmg = rollD(10) + abilityMod(player.abilities.cha) + player.weaponBonus
                    let hexed = t.effects.contains(where: { $0.effect == .poisoned }) // reusing poisoned as hex marker
                    if hexed { dmg += rollD(6) }
                    if roll - abilityMod(player.abilities.cha) == 20 { dmg *= 2; addNarration("CRITICAL HIT!"); screenShake() }
                    t.hp -= dmg
                    addNarration("Eldritch Blast hits \(t.type.rawValue) for \(dmg)!")
                    animateAttack(from: player.node, to: t.node)
                } else { addNarration("Eldritch Blast misses!") }
            case 2: // Hex
                guard let uses = player.abilityUses[2], uses > 0 else { addNarration("No uses left!"); return }
                player.abilityUses[2] = uses - 1
                t.effects.append(ActiveEffect(effect: .poisoned, turnsRemaining: 99, value: 0))
                addNarration("Hex placed on \(t.type.rawValue)! +d6 on all attacks against it.")
            case 3: // Dark Pact
                if player.pactPoints < 2 { addNarration("Need 2 pact points!"); return }
                player.pactPoints -= 2; player.hp -= 10
                if player.hp <= 0 { handlePlayerDeath(); return }
                player.effects.append(ActiveEffect(effect: .blessed, turnsRemaining: 1, value: 24)) // massive next-attack bonus
                addNarration("Dark Pact! -10 HP. Next attack deals +4d6!")
            case 4: // Summon Familiar
                if player.pactPoints < 3 { addNarration("Need 3 pact points!"); return }
                player.pactPoints -= 3
                player.familiarHP = 10; player.familiarTurns = 5
                player.familiarGridX = player.gridX + 1; player.familiarGridZ = player.gridZ
                let imp = SCNSphere(radius: CGFloat(0.15))
                imp.firstMaterial?.diffuse.contents = NSColor(red: 0.5, green: 0, blue: 0, alpha: 1)
                imp.firstMaterial?.emission.contents = NSColor(red: 0.3, green: 0, blue: 0, alpha: 1)
                let impNode = SCNNode(geometry: imp)
                impNode.position = SCNVector3(CGFloat(player.familiarGridX), CGFloat(0.3), CGFloat(player.familiarGridZ))
                scene.rootNode.addChildNode(impNode); player.familiarNode = impNode; dungeonTileNodes.append(impNode)
                addNarration("An imp materializes beside you!")
            default: break
            }
        }
        checkMonsterDeaths()
        showAbilityButtons()
        updateHUD()
    }

    func nearestMonster() -> MonsterCharacter? {
        var best: MonsterCharacter? = nil; var bestDist = 999
        for m in monsters where m.hp > 0 {
            let d = abs(player.gridX - m.gridX) + abs(player.gridZ - m.gridZ)
            if d < bestDist { bestDist = d; best = m }
        }
        return best
    }

    func monsterAt(_ gx: Int, _ gz: Int) -> MonsterCharacter? {
        return monsters.first(where: { $0.hp > 0 && $0.gridX == gx && $0.gridZ == gz })
    }

    func checkMonsterDeaths() {
        for m in monsters where m.hp <= 0 && m.node != nil {
            addNarration("\(m.type.rawValue) defeated!")
            m.node?.removeFromParentNode(); m.node = nil
            let leveled = player.gainXP(m.xpReward)
            if leveled { addNarration("LEVEL UP! Now level \(player.level)!") }
            if player.cls == .warlock { player.pactPoints = min(player.maxPactPoints, player.pactPoints + 1) }
            // Update kill quests
            for i in 0..<player.activeQuests.count {
                if player.activeQuests[i].type == .kill && player.activeQuests[i].targetMonster == m.type {
                    player.activeQuests[i].progress += 1
                    if player.activeQuests[i].progress >= player.activeQuests[i].targetCount && !player.activeQuests[i].completed {
                        player.activeQuests[i].completed = true
                        addNarration("Quest complete: \(player.activeQuests[i].name)! Return to guild.")
                    }
                }
            }
        }
        // Check if combat over
        if monsters.allSatisfy({ $0.hp <= 0 }) && inCombat {
            addNarration("All enemies defeated!")
            inCombat = false
            hideAbilityButtons()
            turnIndicatorLabel.isHidden = true
            if state == .combat && travelDestination != nil {
                // Finish travel after road encounter
                if let dest = travelDestination {
                    currentLocation = dest; travelDestination = nil
                    checkCampaignProgression()
                    enterVillage(dest)
                }
            } else {
                state = .dungeon
            }
        }
    }

    func endPlayerTurn() {
        guard state == .combat else { return }
        // Process player status effects
        var i = 0
        while i < player.effects.count {
            if player.effects[i].effect == .poisoned {
                let dmg = rollD(4)
                player.hp -= dmg
                addNarration("Poison deals \(dmg) damage!")
                if player.hp <= 0 { handlePlayerDeath(); return }
            }
            player.effects[i].turnsRemaining -= 1
            if player.effects[i].turnsRemaining <= 0 { player.effects.remove(at: i) } else { i += 1 }
        }
        // Familiar attack
        if player.familiarHP > 0 && player.familiarTurns > 0 {
            if let ft = nearestMonster() {
                let fd = abs(player.familiarGridX - ft.gridX) + abs(player.familiarGridZ - ft.gridZ)
                if fd <= 2 {
                    let dmg = rollD(4)
                    ft.hp -= dmg
                    addNarration("Imp attacks \(ft.type.rawValue) for \(dmg)!")
                }
            }
            player.familiarTurns -= 1
            if player.familiarTurns <= 0 { player.familiarNode?.removeFromParentNode(); player.familiarHP = 0; addNarration("The imp fades away.") }
        }
        checkMonsterDeaths()
        // Enemy turn
        turnIndicatorLabel.text = "ENEMY TURN"
        enemyTurn()
    }

    func enemyTurn() {
        for m in monsters where m.hp > 0 {
            // Status effects
            var stunned = false
            var ei = 0
            while ei < m.effects.count {
                if m.effects[ei].effect == .stunned { stunned = true }
                if m.effects[ei].effect == .poisoned && m.effects[ei].value > 0 {
                    let dmg = rollD(4); m.hp -= dmg
                }
                m.effects[ei].turnsRemaining -= 1
                if m.effects[ei].turnsRemaining <= 0 { m.effects.remove(at: ei) } else { ei += 1 }
            }
            if stunned { addNarration("\(m.type.rawValue) is stunned!"); continue }

            // Mimic reveal
            if m.type == .mimic && !m.revealed {
                let dist = abs(player.gridX - m.gridX) + abs(player.gridZ - m.gridZ)
                if dist <= 2 { m.revealed = true; m.node?.isHidden = false; addNarration("The chest springs to life! It's a Mimic!") }
                continue
            }

            // Troll regeneration
            if m.specialAbility == "regenerate" { m.hp = min(m.maxHP, m.hp + 5); addNarration("\(m.type.rawValue) regenerates 5 HP.") }

            // Shield (dark mage)
            if m.specialAbility == "shield" && Int.random(in: 0..<3) == 0 { m.shieldActive = true }
            else { m.shieldActive = false }

            let dist = abs(player.gridX - m.gridX) + abs(player.gridZ - m.gridZ)

            // Dragon breath weapon
            if m.specialAbility == "breath_weapon" && !m.breathRecharge && dist <= 3 {
                let dmg = rollDice(count: 6, sides: 6).total
                let save = rollD(20) + abilityMod(player.abilities.dex)
                let actual = save >= 15 ? dmg / 2 : dmg
                player.hp -= actual
                addNarration("The dragon breathes fire! \(actual) damage!")
                m.breathRecharge = true
                screenShake()
                if player.hp <= 0 { handlePlayerDeath(); return }
                continue
            }
            if m.breathRecharge { let recharge = rollD(6); if recharge >= 5 { m.breathRecharge = false } }

            // Ogre ground slam
            if m.specialAbility == "ground_slam" && !m.usedGroundSlam && dist <= 1 {
                m.usedGroundSlam = true
                let dmg = rollD(6)
                player.hp -= dmg; addNarration("Ogre GROUND SLAM! \(dmg) damage!")
                if player.hp <= 0 { handlePlayerDeath(); return }
                continue
            }

            // Ranged attack
            if m.isRanged && dist <= m.range && dist > 1 {
                let roll = rollD(20) + m.attackBonus
                let shieldReduction = player.effects.filter({$0.effect == .shielded}).reduce(0,{$0+$1.value})
                if roll >= player.effectiveAC {
                    let dmg = max(0, rollDice(count: m.attackDice, sides: m.attackSides).total + m.attackBonus - shieldReduction)
                    if m.specialAbility == "life_drain" { m.hp = min(m.maxHP, m.hp + dmg/2) }
                    player.hp -= dmg
                    addNarration("\(m.type.rawValue) hits you for \(dmg)!")
                    if player.hp <= 0 { handlePlayerDeath(); return }
                } else { addNarration("\(m.type.rawValue)'s attack misses!") }
                continue
            }

            // Move toward player
            if dist > 1 {
                let dx = player.gridX > m.gridX ? 1 : (player.gridX < m.gridX ? -1 : 0)
                let dz = player.gridZ > m.gridZ ? 1 : (player.gridZ < m.gridZ ? -1 : 0)
                let nx = m.gridX + dx; let nz = m.gridZ + dz
                if nx >= 0 && nx < dungeonGen.width && nz >= 0 && nz < dungeonGen.height {
                    let tile = dungeonGen.grid[nz][nx]
                    if tile != 0 && monsterAt(nx, nz) == nil {
                        m.gridX = nx; m.gridZ = nz
                        m.node?.runAction(SCNAction.move(to: SCNVector3(CGFloat(nx), CGFloat(0.05), CGFloat(nz)), duration: 0.3))
                    }
                }
            }

            // Melee attack
            let newDist = abs(player.gridX - m.gridX) + abs(player.gridZ - m.gridZ)
            if newDist <= 1 {
                let roll = rollD(20) + m.attackBonus
                let shieldReduction = player.effects.filter({$0.effect == .shielded}).reduce(0,{$0+$1.value})
                // Orc rage
                var bonus = 0
                if m.specialAbility == "rage" && m.hp <= m.maxHP / 2 { bonus = 2 }
                if roll >= player.effectiveAC {
                    let dmg = max(0, rollDice(count: m.attackDice, sides: m.attackSides).total + m.attackBonus + bonus - shieldReduction)
                    if m.specialAbility == "life_drain" { m.hp = min(m.maxHP, m.hp + dmg/2); addNarration("The wraith drains your life force!") }
                    player.hp -= dmg
                    let flavor: String
                    switch m.type {
                    case .giantRat: flavor = "The rat bites!"
                    case .goblin: flavor = "The goblin slashes!"
                    case .orcBerserker: flavor = "The orc's greataxe crashes down!"
                    case .troll: flavor = "The troll swings its massive arm!"
                    case .youngDragon: flavor = "The dragon's fangs sink in!"
                    default: flavor = "\(m.type.rawValue) attacks!"
                    }
                    addNarration("\(flavor) \(dmg) damage!")
                    // Spider poison
                    if m.specialAbility == "web_poison" && Int.random(in: 0..<2) == 0 {
                        player.effects.append(ActiveEffect(effect: .poisoned, turnsRemaining: 3, value: 0))
                        addNarration("You've been poisoned!")
                    }
                    if player.hp <= 0 { handlePlayerDeath(); return }
                } else { addNarration("\(m.type.rawValue) misses!") }
            }
            m.hasActed = true
        }
        // Start next player turn
        player.movementLeft = player.speed
        for i in 0..<monsters.count { monsters[i].hasActed = false }
        turnIndicatorLabel.text = "YOUR TURN"
        showAbilityButtons()
        updateHUD()
    }

    // MARK: - Visual Effects
    func animateAttack(from: SCNNode?, to: SCNNode?) {
        guard let f = from, let t = to else { return }
        let original = f.position
        let moveToTarget = SCNAction.move(to: SCNVector3(
            (original.x + t.position.x) / CGFloat(2),
            original.y,
            (original.z + t.position.z) / CGFloat(2)
        ), duration: 0.15)
        let moveBack = SCNAction.move(to: original, duration: 0.15)
        f.runAction(SCNAction.sequence([moveToTarget, moveBack]))
        // Flash target red
        let flashOn = SCNAction.customAction(duration: 0.1) { node, _ in
            node.geometry?.firstMaterial?.emission.contents = NSColor.red
        }
        let flashOff = SCNAction.customAction(duration: 0.1) { node, _ in
            node.geometry?.firstMaterial?.emission.contents = NSColor.black
        }
        t.runAction(SCNAction.sequence([flashOn, flashOff]))
    }

    func animateFireball(at target: SCNNode?) {
        guard let t = target else { return }
        let fireball = SCNSphere(radius: CGFloat(0.3))
        fireball.firstMaterial?.diffuse.contents = NSColor.orange
        fireball.firstMaterial?.emission.contents = NSColor.red
        let fn = SCNNode(geometry: fireball)
        fn.position = t.position
        scene.rootNode.addChildNode(fn)
        let expand = SCNAction.scale(to: CGFloat(5), duration: 0.3)
        let fade = SCNAction.fadeOut(duration: 0.3)
        let remove = SCNAction.removeFromParentNode()
        fn.runAction(SCNAction.sequence([expand, fade, remove]))
    }

    func screenShake() {
        let originalPos = cameraNode.position
        let shake = SCNAction.sequence([
            SCNAction.moveBy(x: CGFloat(0.2), y: CGFloat(0), z: CGFloat(0), duration: 0.05),
            SCNAction.moveBy(x: CGFloat(-0.4), y: CGFloat(0), z: CGFloat(0), duration: 0.05),
            SCNAction.moveBy(x: CGFloat(0.3), y: CGFloat(0.1), z: CGFloat(0), duration: 0.05),
            SCNAction.moveBy(x: CGFloat(-0.1), y: CGFloat(-0.1), z: CGFloat(0), duration: 0.05),
            SCNAction.move(to: originalPos, duration: 0.05),
        ])
        cameraNode.runAction(shake)
    }

    // MARK: - Click Handling
    func handleClick(at point: CGPoint, in view: SCNView) {
        // Check overlay (SpriteKit) first
        let skNodes = overlay.nodes(at: point)
        for skNode in skNodes {
            guard let name = skNode.name else { continue }

            // Main menu class selection
            if name.hasPrefix("class_") {
                let clsName = String(name.dropFirst(6))
                if let cls = CharacterClass(rawValue: clsName) { selectClass(cls); return }
            }

            // Game over / victory restart
            if name == "gameover" || name == "victory" {
                for n in menuNodes { n.removeFromParent() }; menuNodes.removeAll()
                showMainMenu(); return
            }

            // Dialogue responses
            if name.hasPrefix("dlg_") {
                if let idx = Int(String(name.dropFirst(4))) { handleDialogueResponse(idx); return }
            }

            // Quest board
            if name.hasPrefix("accept_") {
                if let idx = Int(String(name.dropFirst(7))) { acceptQuest(idx); return }
            }
            if name.hasPrefix("turnin_") {
                let qid = String(name.dropFirst(7)); turnInQuest(qid); return
            }
            if name == "close_quest" { clearQuestBoard(); state = .village; updateHUD(); return }

            // Shop
            if name.hasPrefix("buy_") {
                if let idx = Int(String(name.dropFirst(4))) { buyItem(idx); return }
            }
            if name == "close_shop" { clearShop(); state = .village; updateHUD(); return }

            // Inventory
            if name.hasPrefix("use_") {
                if let idx = Int(String(name.dropFirst(4))) { useItem(idx); return }
            }
            if name.hasPrefix("drop_") {
                if let idx = Int(String(name.dropFirst(5))) {
                    if idx < player.inventory.count {
                        addNarration("Dropped \(player.inventory[idx].name).")
                        player.inventory.remove(at: idx)
                        clearInventory(); showInventory()
                    }
                    return
                }
            }
            if name == "close_inv" {
                clearInventory()
                state = inCombat ? .combat : (currentDungeon.isEmpty ? .village : .dungeon)
                updateHUD(); return
            }

            // World map
            if name.hasPrefix("maploc_") {
                let locName = String(name.dropFirst(7))
                if let loc = LocationID(rawValue: locName) { travelTo(loc); return }
            }

            // Ability buttons
            if name.hasPrefix("ability_") {
                if let num = Int(String(name.dropFirst(8))) { useAbility(num); return }
            }
            if name == "end_turn" { endPlayerTurn(); return }
        }

        // 3D scene hit test
        let hitResults = view.hitTest(point, options: [SCNHitTestOption.searchMode: SCNHitTestSearchMode.closest.rawValue])

        switch state {
        case .village:
            handleVillageClick(hitResults: hitResults, point: point, view: view)
        case .dungeon:
            handleDungeonClick(hitResults: hitResults, point: point, view: view)
        case .combat:
            handleCombatClick(hitResults: hitResults, point: point, view: view)
        default:
            break
        }
    }

    func handleVillageClick(hitResults: [SCNHitTestResult], point: CGPoint, view: SCNView) {
        guard let hit = hitResults.first else { return }
        let worldPos = hit.worldCoordinates
        let targetX = Int(round(Double(worldPos.x)))
        let targetZ = Int(round(Double(worldPos.z)))

        // Check if clicked on NPC
        for (npc, npcNode) in npcNodes {
            let npcX = Int(round(Double(npcNode.position.x)))
            let npcZ = Int(round(Double(npcNode.position.z)))
            if abs(targetX - npcX) <= 1 && abs(targetZ - npcZ) <= 1 {
                showDialogue(npc); return
            }
        }

        // Check if clicked on building
        for (building, _) in buildingNodes {
            if targetX >= building.gridX && targetX < building.gridX + building.width &&
               targetZ >= building.gridZ && targetZ < building.gridZ + building.depth {
                handleBuildingInteraction(building); return
            }
        }

        // Move player
        let moveAction = SCNAction.move(to: SCNVector3(CGFloat(targetX), CGFloat(0), CGFloat(targetZ)), duration: 0.5)
        player.node?.runAction(moveAction)
        player.gridX = targetX; player.gridZ = targetZ
        // Face direction
        if let pn = player.node {
            pn.look(at: SCNVector3(CGFloat(targetX), pn.position.y, CGFloat(targetZ)))
        }
    }

    func handleBuildingInteraction(_ building: BuildingData) {
        switch building.type {
        case .inn:
            restAtInn()
        case .guild:
            showQuestBoard()
        case .generalShop, .herbShop:
            showShop(items: generalShopItems, type: "General Shop")
        case .blacksmith, .masterForge:
            showBlacksmith()
        case .herbalist:
            showShop(items: herbalistItems, type: "Herbalist")
        case .aleHall:
            if player.gold >= 5 {
                player.gold -= 5
                player.effects.append(ActiveEffect(effect: .blessed, turnsRemaining: 10, value: 2))
                addNarration("A fine dwarven ale! +2 attack for 10 turns.")
            } else { addNarration("Not enough gold for ale! (5g)") }
            updateHUD()
        case .goblinCaves:
            enterDungeon("Goblin Caves")
        case .undeadCrypt:
            enterDungeon("Undead Crypt")
        case .mineEntrance:
            enterDungeon("Ironhold Mine")
        case .swampEntrance:
            enterDungeon("Swamp Dungeon")
        case .dragonLair:
            enterDungeon("Dragon's Lair")
        default:
            addNarration("You examine the \(building.name).")
        }
    }

    func handleDungeonClick(hitResults: [SCNHitTestResult], point: CGPoint, view: SCNView) {
        guard let hit = hitResults.first else { return }
        let worldPos = hit.worldCoordinates
        let targetX = Int(round(Double(worldPos.x)))
        let targetZ = Int(round(Double(worldPos.z)))
        if targetX < 0 || targetX >= dungeonGen.width || targetZ < 0 || targetZ >= dungeonGen.height { return }
        if dungeonGen.grid[targetZ][targetX] == 0 { return } // wall

        // Check for monsters nearby that would trigger combat
        for m in monsters where m.hp > 0 {
            let dist = abs(player.gridX - m.gridX) + abs(player.gridZ - m.gridZ)
            if dist <= 3 && m.revealed {
                startCombat(); return
            }
            // Mimic check
            if m.type == .mimic && !m.revealed {
                let mDist = abs(targetX - m.gridX) + abs(targetZ - m.gridZ)
                if mDist <= 1 { m.revealed = true; m.node?.isHidden = false; addNarration("It's a Mimic!"); startCombat(); return }
            }
        }

        // Move player via path
        let path = bfsPath(grid: dungeonGen.grid, from: (player.gridX, player.gridZ), to: (targetX, targetZ))
        if path.isEmpty { return }
        let truncated = Array(path.prefix(player.speed))
        var actions: [SCNAction] = []
        for step in truncated {
            actions.append(SCNAction.move(to: SCNVector3(CGFloat(step.0), CGFloat(0.05), CGFloat(step.1)), duration: 0.15))
        }
        if let last = truncated.last {
            player.gridX = last.0; player.gridZ = last.1
        }
        player.node?.runAction(SCNAction.sequence(actions)) { [weak self] in
            self?.handleDungeonTileStep()
            // Check if near any monsters now
            guard let s = self else { return }
            for m in s.monsters where m.hp > 0 {
                let dist = abs(s.player.gridX - m.gridX) + abs(s.player.gridZ - m.gridZ)
                if dist <= 2 && m.revealed {
                    s.startCombat(); return
                }
            }
        }
        // Update camera
        cameraNode.runAction(SCNAction.move(to: SCNVector3(CGFloat(player.gridX), CGFloat(15), CGFloat(player.gridZ) + CGFloat(10)), duration: 0.3))
    }

    func handleCombatClick(hitResults: [SCNHitTestResult], point: CGPoint, view: SCNView) {
        guard let hit = hitResults.first else { return }
        let worldPos = hit.worldCoordinates
        let targetX = Int(round(Double(worldPos.x)))
        let targetZ = Int(round(Double(worldPos.z)))

        // Check if clicked on a monster
        if let m = monsterAt(targetX, targetZ) {
            useAbility(1, targetMonster: m); return
        }

        // Movement
        if player.movementLeft > 0 && targetX >= 0 && targetX < dungeonGen.width && targetZ >= 0 && targetZ < dungeonGen.height {
            if dungeonGen.grid[targetZ][targetX] != 0 {
                let dist = abs(targetX - player.gridX) + abs(targetZ - player.gridZ)
                if dist <= player.movementLeft {
                    player.gridX = targetX; player.gridZ = targetZ; player.movementLeft -= dist
                    player.node?.runAction(SCNAction.move(to: SCNVector3(CGFloat(targetX), CGFloat(0.05), CGFloat(targetZ)), duration: 0.2))
                    // Face direction
                    player.node?.look(at: SCNVector3(CGFloat(targetX), CGFloat(0.05), CGFloat(targetZ)))
                    updateHUD()
                } else { addNarration("Not enough movement! (\(player.movementLeft) left)") }
            }
        }
    }

    // MARK: - Key Handling
    func handleKeyDown(event: NSEvent) {
        guard let chars = event.charactersIgnoringModifiers else { return }

        switch chars {
        case "m", "M":
            if state == .village { showWorldMap() }
        case "i", "I":
            if state == .village || state == .dungeon || state == .combat { showInventory() }
        case "q", "Q":
            if state == .village { showQuestBoard() }
        case "e", "E":
            if state == .village { interactNearest() }
        case "1":
            if state == .combat { useAbility(1) }
        case "2":
            if state == .combat { useAbility(2) }
        case "3":
            if state == .combat { useAbility(3) }
        case "4":
            if state == .combat { useAbility(4) }
        case " ":
            if state == .combat { endPlayerTurn() }
        default:
            break
        }

        // Escape key
        if event.keyCode == 53 {
            if state == .worldMap { clearWorldMap(); state = .village; updateHUD() }
            else if state == .dialogue { hideDialogue(); state = .village; updateHUD() }
            else if state == .questBoard { clearQuestBoard(); state = .village; updateHUD() }
            else if state == .shop { clearShop(); state = .village; updateHUD() }
            else if state == .inventory {
                clearInventory()
                state = inCombat ? .combat : (currentDungeon.isEmpty ? .village : .dungeon)
                updateHUD()
            }
        }
    }

    func interactNearest() {
        // Find nearest NPC or building
        var bestDist = 999.0
        var bestNPC: NPCData? = nil
        for (npc, npcNode) in npcNodes {
            let dx = Double(npcNode.position.x) - Double(player.gridX)
            let dz = Double(npcNode.position.z) - Double(player.gridZ)
            let d = sqrt(dx*dx + dz*dz)
            if d < bestDist && d < 3.0 { bestDist = d; bestNPC = npc }
        }
        if let npc = bestNPC { showDialogue(npc); return }

        // Check buildings
        for (building, _) in buildingNodes {
            let bx = building.gridX + building.width / 2
            let bz = building.gridZ + building.depth / 2
            let dx = Double(bx - player.gridX); let dz = Double(bz - player.gridZ)
            let d = sqrt(dx*dx + dz*dz)
            if d < 5.0 { handleBuildingInteraction(building); return }
        }
        addNarration("Nothing to interact with nearby.")
    }
} // End of GameController

// MARK: - Game View (NSView subclass for input)
class GameView: SCNView {
    var controller: GameController?

    override func mouseDown(with event: NSEvent) {
        let loc = event.locationInWindow
        // Convert to view coordinates (flip Y for SpriteKit)
        let viewPoint = self.convert(loc, from: nil)
        controller?.handleClick(at: viewPoint, in: self)
    }

    override func keyDown(with event: NSEvent) {
        controller?.handleKeyDown(event: event)
    }

    override var acceptsFirstResponder: Bool { return true }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var gameView: GameView!
    var controller: GameController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let rect = NSRect(x: 100, y: 100, width: 1280, height: 720)
        window = NSWindow(contentRect: rect,
                          styleMask: [.titled, .closable, .miniaturizable],
                          backing: .buffered, defer: false)
        window.title = "DUNGEONS & DICE // CAMPAIGN"
        window.center()

        gameView = GameView(frame: NSRect(x: 0, y: 0, width: 1280, height: 720))
        gameView.allowsCameraControl = false
        gameView.showsStatistics = false
        gameView.backgroundColor = NSColor.black
        window.contentView = gameView

        controller = GameController(scnView: gameView)
        gameView.controller = controller

        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(gameView)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

// MARK: - Main Entry
let delegate = AppDelegate()
let app = NSApplication.shared
app.delegate = delegate
app.setActivationPolicy(.regular)
app.activate(ignoringOtherApps: true)
app.run()
