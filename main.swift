import AppKit
import SceneKit
import SpriteKit
import Foundation

// MARK: - Dice Functions
func rollD(_ n: Int) -> Int { Int.random(in: 1...n) }
func roll4d6DropLowest() -> Int {
    var rolls: [Int] = []
    for _ in 0..<4 { rolls.append(rollD(6)) }
    rolls.sort()
    return rolls[1] + rolls[2] + rolls[3]
}
func rollDice(count: Int, sides: Int) -> (rolls: [Int], total: Int) {
    var rolls: [Int] = []
    var total = 0
    for _ in 0..<count {
        let r = rollD(sides)
        rolls.append(r)
        total += r
    }
    return (rolls, total)
}
func abilityMod(_ score: Int) -> Int { (score - 10) / 2 }

// MARK: - Enums
enum CharacterClass: String {
    case fighter = "FIGHTER"
    case rogue = "ROGUE"
    case cleric = "CLERIC"
    case wizard = "WIZARD"
    case warlock = "WARLOCK"
}
enum GameState: String {
    case classSelect, playerTurn, enemyTurn, animating, levelUp, dead, stairs
}
enum MonsterType: String {
    case giantRat = "Giant Rat"
    case goblin = "Goblin"
    case skeleton = "Skeleton"
    case orc = "Orc"
    case ogre = "Ogre"
    case youngDragon = "Young Dragon"
}

// MARK: - Ability Scores
struct AbilityScores {
    var str: Int = 10; var dex: Int = 10; var con: Int = 10
    var intel: Int = 10; var wis: Int = 10; var cha: Int = 10
    static func generate(forClass cls: CharacterClass) -> AbilityScores {
        var rolls: [Int] = []
        for _ in 0..<6 { rolls.append(roll4d6DropLowest()) }
        rolls.sort(by: >)
        var s = AbilityScores()
        switch cls {
        case .fighter:
            s.str = rolls[0]; s.con = rolls[1]; s.dex = rolls[2]
            s.wis = rolls[3]; s.cha = rolls[4]; s.intel = rolls[5]
        case .rogue:
            s.dex = rolls[0]; s.con = rolls[1]; s.intel = rolls[2]
            s.wis = rolls[3]; s.cha = rolls[4]; s.str = rolls[5]
        case .cleric:
            s.wis = rolls[0]; s.con = rolls[1]; s.str = rolls[2]
            s.cha = rolls[3]; s.dex = rolls[4]; s.intel = rolls[5]
        case .wizard:
            s.intel = rolls[0]; s.con = rolls[1]; s.dex = rolls[2]
            s.wis = rolls[3]; s.cha = rolls[4]; s.str = rolls[5]
        case .warlock:
            s.cha = rolls[0]; s.con = rolls[1]; s.dex = rolls[2]
            s.wis = rolls[3]; s.intel = rolls[4]; s.str = rolls[5]
        }
        return s
    }
}

// MARK: - Player Character
class PlayerCharacter {
    var cls: CharacterClass
    var level: Int = 1
    var scores: AbilityScores
    var maxHP: Int = 0; var hp: Int = 0
    var ac: Int = 10
    var xp: Int = 0; var gold: Int = 0; var kills: Int = 0
    var gridX: Int = 0; var gridY: Int = 0
    var movementLeft: Int = 0; var hasAction: Bool = true
    var ability1Uses: Int = 0; var ability2Uses: Int = 0
    var potions: Int = 0
    var hexActive: Bool = false
    var node: SCNNode?

    var speed: Int { return 30 }
    var movementTiles: Int { return speed / 2 }
    var attackMod: Int {
        switch cls {
        case .fighter: return abilityMod(scores.str) + profBonus
        case .rogue: return abilityMod(scores.dex) + profBonus
        case .cleric: return abilityMod(scores.str) + profBonus
        case .wizard: return abilityMod(scores.intel) + profBonus
        case .warlock: return abilityMod(scores.cha) + profBonus
        }
    }
    var profBonus: Int { return 2 + (level - 1) / 4 }
    var primaryStat: Int {
        switch cls {
        case .fighter: return scores.str
        case .rogue: return scores.dex
        case .cleric: return scores.wis
        case .wizard: return scores.intel
        case .warlock: return scores.cha
        }
    }

    static let xpThresholds = [100, 300, 600, 1000, 1500, 2100]

    init(cls: CharacterClass) {
        self.cls = cls
        self.scores = AbilityScores.generate(forClass: cls)
        switch cls {
        case .fighter:
            maxHP = 12 + abilityMod(scores.con); ac = 16
        case .rogue:
            maxHP = 8 + abilityMod(scores.con); ac = 14
        case .cleric:
            maxHP = 10 + abilityMod(scores.con); ac = 16
        case .wizard:
            maxHP = 6 + abilityMod(scores.con); ac = 12
        case .warlock:
            maxHP = 8 + abilityMod(scores.con); ac = 13
        }
        if maxHP < 1 { maxHP = 1 }
        hp = maxHP
        resetAbilities()
    }

    func resetAbilities() {
        switch cls {
        case .fighter: ability1Uses = 1; ability2Uses = 1
        case .rogue: ability1Uses = 99; ability2Uses = 99
        case .cleric: ability1Uses = 3; ability2Uses = 3
        case .wizard: ability1Uses = 3; ability2Uses = 1
        case .warlock: ability1Uses = 99; ability2Uses = 2
        }
    }

    func refreshFloor() {
        resetAbilities()
        hexActive = false
    }

    func startTurn() {
        movementLeft = movementTiles
        hasAction = true
    }

    func canLevelUp() -> Bool {
        if level >= 7 { return false }
        return xp >= PlayerCharacter.xpThresholds[level - 1]
    }

    func levelUp() {
        level += 1
        let hitDie: Int
        switch cls {
        case .fighter: hitDie = 8
        case .rogue: hitDie = 6
        case .cleric: hitDie = 8
        case .wizard: hitDie = 4
        case .warlock: hitDie = 8
        }
        let hpGain = max(1, rollD(hitDie) + abilityMod(scores.con))
        maxHP += hpGain
        hp = maxHP
        switch cls {
        case .fighter: if scores.str < 20 { scores.str += 1 }
        case .rogue: if scores.dex < 20 { scores.dex += 1 }
        case .cleric: if scores.wis < 20 { scores.wis += 1 }
        case .wizard: if scores.intel < 20 { scores.intel += 1 }
        case .warlock: if scores.cha < 20 { scores.cha += 1 }
        }
        resetAbilities()
    }

    var damageDice: (count: Int, sides: Int, bonus: Int) {
        switch cls {
        case .fighter: return (1, 8, abilityMod(scores.str))
        case .rogue: return (1, 6, abilityMod(scores.dex))
        case .cleric: return (1, 6, abilityMod(scores.str))
        case .wizard: return (1, 4, abilityMod(scores.intel))
        case .warlock: return (1, 10, abilityMod(scores.cha))
        }
    }

    var ability1Name: String {
        switch cls {
        case .fighter: return "Second Wind"
        case .rogue: return "Cunning Action"
        case .cleric: return "Healing Word"
        case .wizard: return "Magic Missile"
        case .warlock: return "Eldritch Blast"
        }
    }
    var ability2Name: String {
        switch cls {
        case .fighter: return "Action Surge"
        case .rogue: return "Evasion"
        case .cleric: return "Sacred Flame"
        case .wizard: return "Fireball"
        case .warlock: return "Hex"
        }
    }
}

// MARK: - Monster
class Monster {
    var type: MonsterType
    var maxHP: Int; var hp: Int; var ac: Int
    var attackBonus: Int; var damageDice: Int; var damageCount: Int; var damageBonus: Int
    var speedTiles: Int; var xpValue: Int
    var gridX: Int; var gridY: Int
    var node: SCNNode?
    var hasActed: Bool = false
    var breathRecharge: Int = 0

    init(type: MonsterType, x: Int, y: Int) {
        self.type = type; self.gridX = x; self.gridY = y
        switch type {
        case .giantRat:
            maxHP = 7; ac = 12; attackBonus = 4; damageDice = 4; damageCount = 1
            damageBonus = 2; speedTiles = 2; xpValue = 25
        case .goblin:
            maxHP = 7; ac = 15; attackBonus = 4; damageDice = 6; damageCount = 1
            damageBonus = 2; speedTiles = 2; xpValue = 50
        case .skeleton:
            maxHP = 13; ac = 13; attackBonus = 4; damageDice = 6; damageCount = 1
            damageBonus = 2; speedTiles = 2; xpValue = 100
        case .orc:
            maxHP = 15; ac = 13; attackBonus = 5; damageDice = 12; damageCount = 1
            damageBonus = 3; speedTiles = 2; xpValue = 150
        case .ogre:
            maxHP = 59; ac = 11; attackBonus = 6; damageDice = 8; damageCount = 2
            damageBonus = 4; speedTiles = 1; xpValue = 300
        case .youngDragon:
            maxHP = 75; ac = 18; attackBonus = 7; damageDice = 10; damageCount = 1
            damageBonus = 4; speedTiles = 3; xpValue = 500
        }
        hp = maxHP
    }
}

// MARK: - Dungeon Tile
enum TileType: Int {
    case wall = 0; case floor = 1; case stairs = 2; case trap = 3; case chest = 4
}

// MARK: - Dungeon Generation
struct Room {
    var x: Int; var y: Int; var w: Int; var h: Int
    var centerX: Int { return x + w / 2 }
    var centerY: Int { return y + h / 2 }
}

class Dungeon {
    static let size = 32
    var tiles: [[TileType]]
    var rooms: [Room] = []
    var explored: [[Bool]]
    var stairsX: Int = 0; var stairsY: Int = 0
    var spawnX: Int = 0; var spawnY: Int = 0

    init() {
        tiles = Array(repeating: Array(repeating: TileType.wall, count: Dungeon.size), count: Dungeon.size)
        explored = Array(repeating: Array(repeating: false, count: Dungeon.size), count: Dungeon.size)
    }

    func isWalkable(_ x: Int, _ y: Int) -> Bool {
        guard x >= 0, y >= 0, x < Dungeon.size, y < Dungeon.size else { return false }
        let t = tiles[y][x]
        return t == .floor || t == .stairs || t == .trap || t == .chest
    }

    func generate(floor: Int) {
        for y in 0..<Dungeon.size {
            for x in 0..<Dungeon.size {
                tiles[y][x] = .wall
                explored[y][x] = false
            }
        }
        rooms.removeAll()
        let targetRooms = min(10, 5 + floor)
        var attempts = 0
        while rooms.count < targetRooms && attempts < 200 {
            attempts += 1
            let w = Int.random(in: 4...8)
            let h = Int.random(in: 4...8)
            let rx = Int.random(in: 1...(Dungeon.size - w - 1))
            let ry = Int.random(in: 1...(Dungeon.size - h - 1))
            let newRoom = Room(x: rx, y: ry, w: w, h: h)
            var overlaps = false
            for existing in rooms {
                if newRoom.x - 1 < existing.x + existing.w && newRoom.x + newRoom.w + 1 > existing.x &&
                   newRoom.y - 1 < existing.y + existing.h && newRoom.y + newRoom.h + 1 > existing.y {
                    overlaps = true; break
                }
            }
            if overlaps { continue }
            for y in newRoom.y..<(newRoom.y + newRoom.h) {
                for x in newRoom.x..<(newRoom.x + newRoom.w) {
                    tiles[y][x] = .floor
                }
            }
            if rooms.count > 0 {
                let prev = rooms.last!
                carveCorridor(from: (prev.centerX, prev.centerY), to: (newRoom.centerX, newRoom.centerY))
            }
            rooms.append(newRoom)
        }
        // Spawn in first room
        if let first = rooms.first {
            spawnX = first.centerX; spawnY = first.centerY
        }
        // Stairs in farthest room
        var maxDist: Double = 0
        var farthest = rooms.last ?? rooms[0]
        for room in rooms {
            let dx = Double(room.centerX - spawnX)
            let dy = Double(room.centerY - spawnY)
            let dist = sqrt(dx * dx + dy * dy)
            if dist > maxDist { maxDist = dist; farthest = room }
        }
        stairsX = farthest.centerX; stairsY = farthest.centerY
        tiles[stairsY][stairsX] = .stairs
        // Add traps
        for room in rooms {
            if Bool.random() && room.centerX != spawnX {
                let tx = Int.random(in: room.x..<(room.x + room.w))
                let ty = Int.random(in: room.y..<(room.y + room.h))
                if tiles[ty][tx] == .floor && !(tx == spawnX && ty == spawnY) {
                    tiles[ty][tx] = .trap
                }
            }
        }
        // Add chests
        for room in rooms {
            if Int.random(in: 0..<3) == 0 && room.centerX != spawnX {
                let cx = room.x + 1; let cy = room.y + 1
                if tiles[cy][cx] == .floor {
                    tiles[cy][cx] = .chest
                }
            }
        }
    }

    func carveCorridor(from: (Int, Int), to: (Int, Int)) {
        var cx = from.0; var cy = from.1
        let tx = to.0; let ty = to.1
        // L-shaped corridor
        while cx != tx {
            if cx >= 0 && cx < Dungeon.size && cy >= 0 && cy < Dungeon.size {
                tiles[cy][cx] = .floor
                // Widen corridor
                if cy + 1 < Dungeon.size { tiles[cy + 1][cx] = .floor }
            }
            cx += (tx > cx) ? 1 : -1
        }
        while cy != ty {
            if cx >= 0 && cx < Dungeon.size && cy >= 0 && cy < Dungeon.size {
                tiles[cy][cx] = .floor
                if cx + 1 < Dungeon.size { tiles[cy][cx + 1] = .floor }
            }
            cy += (ty > cy) ? 1 : -1
        }
        if cx >= 0 && cx < Dungeon.size && cy >= 0 && cy < Dungeon.size {
            tiles[cy][cx] = .floor
        }
    }

    func revealAround(_ x: Int, _ y: Int, radius: Int = 5) {
        for dy in -radius...radius {
            for dx in -radius...radius {
                let nx = x + dx; let ny = y + dy
                if nx >= 0 && ny >= 0 && nx < Dungeon.size && ny < Dungeon.size {
                    explored[ny][nx] = true
                }
            }
        }
    }
}

// MARK: - Color Helpers
func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> NSColor {
    return NSColor(red: r, green: g, blue: b, alpha: 1.0)
}

// MARK: - Node Builders
func buildFloorTile(x: Int, y: Int, type: TileType) -> SCNNode {
    let tileSize: CGFloat = 2.0
    let geo = SCNBox(width: tileSize, height: 0.1, length: tileSize, chamferRadius: 0)
    let mat = SCNMaterial()
    switch type {
    case .floor:
        let shade: CGFloat = (x + y) % 2 == 0 ? 0.18 : 0.22
        mat.diffuse.contents = rgb(shade, shade, shade + 0.02)
    case .stairs:
        mat.diffuse.contents = rgb(0.6, 0.5, 0.1)
        mat.emission.contents = rgb(0.2, 0.15, 0.0)
    case .trap:
        mat.diffuse.contents = rgb(0.25, 0.15, 0.15)
    case .chest:
        mat.diffuse.contents = rgb(0.2, 0.2, 0.2)
    default:
        mat.diffuse.contents = rgb(0.2, 0.2, 0.2)
    }
    geo.materials = [mat]
    let node = SCNNode(geometry: geo)
    node.position = SCNVector3(CGFloat(x) * tileSize, CGFloat(0), CGFloat(y) * tileSize)
    return node
}

func buildWall(x: Int, y: Int) -> SCNNode {
    let tileSize: CGFloat = 2.0
    let wallH: CGFloat = 3.5
    let geo = SCNBox(width: tileSize, height: wallH, length: tileSize, chamferRadius: 0)
    let mat = SCNMaterial()
    let shade: CGFloat = CGFloat.random(in: 0.12...0.16)
    mat.diffuse.contents = rgb(shade, shade, shade)
    geo.materials = [mat]
    let node = SCNNode(geometry: geo)
    node.position = SCNVector3(CGFloat(x) * tileSize, wallH / 2.0, CGFloat(y) * tileSize)
    return node
}

func buildChest(x: Int, y: Int) -> SCNNode {
    let tileSize: CGFloat = 2.0
    let geo = SCNBox(width: 0.8, height: 0.6, length: 0.6, chamferRadius: 0.05)
    let mat = SCNMaterial()
    mat.diffuse.contents = rgb(0.7, 0.55, 0.1)
    mat.emission.contents = rgb(0.15, 0.1, 0.0)
    geo.materials = [mat]
    let node = SCNNode(geometry: geo)
    node.position = SCNVector3(CGFloat(x) * tileSize, CGFloat(0.35), CGFloat(y) * tileSize)
    return node
}

func buildStairsModel(x: Int, y: Int) -> SCNNode {
    let tileSize: CGFloat = 2.0
    let parent = SCNNode()
    for i in 0..<4 {
        let step = SCNBox(width: 1.5 - CGFloat(i) * 0.2, height: 0.25, length: 0.4, chamferRadius: 0)
        let mat = SCNMaterial()
        mat.diffuse.contents = rgb(0.5, 0.4, 0.1)
        mat.emission.contents = rgb(0.15, 0.1, 0.0)
        step.materials = [mat]
        let sn = SCNNode(geometry: step)
        sn.position = SCNVector3(CGFloat(0), CGFloat(i) * 0.25 + 0.15, CGFloat(i) * 0.3 - 0.4)
        parent.addChildNode(sn)
    }
    parent.position = SCNVector3(CGFloat(x) * tileSize, CGFloat(0), CGFloat(y) * tileSize)
    return parent
}

// MARK: - Character Model Builders
func buildPlayerModel(cls: CharacterClass) -> SCNNode {
    let parent = SCNNode()
    switch cls {
    case .fighter:
        // Torso - wide box
        let torso = SCNBox(width: 0.7, height: 0.8, length: 0.5, chamferRadius: 0.05)
        let torsoMat = SCNMaterial(); torsoMat.diffuse.contents = rgb(0.4, 0.4, 0.45)
        torso.materials = [torsoMat]
        let torsoN = SCNNode(geometry: torso); torsoN.position = SCNVector3(0, 0.9 as CGFloat, 0)
        parent.addChildNode(torsoN)
        // Head
        let head = SCNSphere(radius: 0.25)
        let headMat = SCNMaterial(); headMat.diffuse.contents = rgb(0.85, 0.7, 0.6)
        head.materials = [headMat]
        let headN = SCNNode(geometry: head); headN.position = SCNVector3(0, 1.55 as CGFloat, 0)
        parent.addChildNode(headN)
        // Sword
        let sword = SCNCylinder(radius: 0.04, height: 1.0)
        let swordMat = SCNMaterial(); swordMat.diffuse.contents = rgb(0.7, 0.7, 0.8)
        swordMat.emission.contents = rgb(0.1, 0.1, 0.15)
        sword.materials = [swordMat]
        let swordN = SCNNode(geometry: sword)
        swordN.position = SCNVector3(0.55 as CGFloat, 1.0 as CGFloat, 0)
        swordN.eulerAngles = SCNVector3(0, 0, CGFloat.pi / 6)
        parent.addChildNode(swordN)
        // Shield
        let shield = SCNBox(width: 0.1, height: 0.5, length: 0.4, chamferRadius: 0.05)
        let shieldMat = SCNMaterial(); shieldMat.diffuse.contents = rgb(0.5, 0.3, 0.1)
        shield.materials = [shieldMat]
        let shieldN = SCNNode(geometry: shield)
        shieldN.position = SCNVector3(-0.5 as CGFloat, 0.9 as CGFloat, 0)
        parent.addChildNode(shieldN)
    case .rogue:
        let body = SCNCapsule(capRadius: 0.2, height: 1.2)
        let bodyMat = SCNMaterial(); bodyMat.diffuse.contents = rgb(0.15, 0.15, 0.2)
        body.materials = [bodyMat]
        let bodyN = SCNNode(geometry: body); bodyN.position = SCNVector3(0, 0.8 as CGFloat, 0)
        parent.addChildNode(bodyN)
        let head = SCNSphere(radius: 0.22)
        let headMat = SCNMaterial(); headMat.diffuse.contents = rgb(0.8, 0.65, 0.55)
        head.materials = [headMat]
        let headN = SCNNode(geometry: head); headN.position = SCNVector3(0, 1.55 as CGFloat, 0)
        parent.addChildNode(headN)
        let dagger = SCNCylinder(radius: 0.025, height: 0.5)
        let dMat = SCNMaterial(); dMat.diffuse.contents = rgb(0.6, 0.6, 0.7)
        dagger.materials = [dMat]
        let dN = SCNNode(geometry: dagger)
        dN.position = SCNVector3(0.35 as CGFloat, 0.8 as CGFloat, 0)
        parent.addChildNode(dN)
    case .cleric:
        let robe = SCNCone(topRadius: 0.2, bottomRadius: 0.5, height: 1.3)
        let robeMat = SCNMaterial(); robeMat.diffuse.contents = rgb(0.8, 0.75, 0.6)
        robe.materials = [robeMat]
        let robeN = SCNNode(geometry: robe); robeN.position = SCNVector3(0, 0.65 as CGFloat, 0)
        parent.addChildNode(robeN)
        let head = SCNSphere(radius: 0.23)
        let headMat = SCNMaterial(); headMat.diffuse.contents = rgb(0.82, 0.68, 0.58)
        head.materials = [headMat]
        let headN = SCNNode(geometry: head); headN.position = SCNVector3(0, 1.55 as CGFloat, 0)
        parent.addChildNode(headN)
        let halo = SCNTorus(ringRadius: 0.3, pipeRadius: 0.03)
        let haloMat = SCNMaterial(); haloMat.diffuse.contents = rgb(0.9, 0.8, 0.2)
        haloMat.emission.contents = rgb(0.4, 0.35, 0.05)
        halo.materials = [haloMat]
        let haloN = SCNNode(geometry: halo); haloN.position = SCNVector3(0, 1.85 as CGFloat, 0)
        parent.addChildNode(haloN)
        let mace = SCNCylinder(radius: 0.04, height: 0.8)
        let maceMat = SCNMaterial(); maceMat.diffuse.contents = rgb(0.5, 0.5, 0.5)
        mace.materials = [maceMat]
        let maceN = SCNNode(geometry: mace)
        maceN.position = SCNVector3(0.45 as CGFloat, 0.8 as CGFloat, 0)
        parent.addChildNode(maceN)
    case .wizard:
        let robe = SCNCone(topRadius: 0.15, bottomRadius: 0.5, height: 1.5)
        let robeMat = SCNMaterial(); robeMat.diffuse.contents = rgb(0.3, 0.1, 0.5)
        robe.materials = [robeMat]
        let robeN = SCNNode(geometry: robe); robeN.position = SCNVector3(0, 0.75 as CGFloat, 0)
        parent.addChildNode(robeN)
        let head = SCNSphere(radius: 0.22)
        let headMat = SCNMaterial(); headMat.diffuse.contents = rgb(0.8, 0.7, 0.6)
        head.materials = [headMat]
        let headN = SCNNode(geometry: head); headN.position = SCNVector3(0, 1.7 as CGFloat, 0)
        parent.addChildNode(headN)
        // Hat
        let hat = SCNCone(topRadius: 0.0, bottomRadius: 0.28, height: 0.45)
        let hatMat = SCNMaterial(); hatMat.diffuse.contents = rgb(0.25, 0.05, 0.45)
        hat.materials = [hatMat]
        let hatN = SCNNode(geometry: hat); hatN.position = SCNVector3(0, 2.05 as CGFloat, 0)
        parent.addChildNode(hatN)
        // Staff
        let staff = SCNCylinder(radius: 0.03, height: 1.8)
        let staffMat = SCNMaterial(); staffMat.diffuse.contents = rgb(0.4, 0.25, 0.1)
        staff.materials = [staffMat]
        let staffN = SCNNode(geometry: staff)
        staffN.position = SCNVector3(0.4 as CGFloat, 0.9 as CGFloat, 0)
        parent.addChildNode(staffN)
        // Orb on top of staff
        let orb = SCNSphere(radius: 0.1)
        let orbMat = SCNMaterial()
        orbMat.diffuse.contents = rgb(0.3, 0.5, 1.0)
        orbMat.emission.contents = rgb(0.2, 0.3, 0.8)
        orb.materials = [orbMat]
        let orbN = SCNNode(geometry: orb)
        orbN.position = SCNVector3(0.4 as CGFloat, 1.85 as CGFloat, 0)
        parent.addChildNode(orbN)
    case .warlock:
        // Dark tattered robe
        let robe = SCNCone(topRadius: 0.18, bottomRadius: 0.5, height: 1.4)
        let robeMat = SCNMaterial(); robeMat.diffuse.contents = rgb(0.15, 0.08, 0.2)
        robeMat.emission.contents = rgb(0.05, 0.0, 0.08)
        robe.materials = [robeMat]
        let robeN = SCNNode(geometry: robe); robeN.position = SCNVector3(0, 0.7 as CGFloat, 0)
        parent.addChildNode(robeN)
        // Head
        let head = SCNSphere(radius: 0.22)
        let headMat = SCNMaterial(); headMat.diffuse.contents = rgb(0.75, 0.6, 0.5)
        head.materials = [headMat]
        let headN = SCNNode(geometry: head); headN.position = SCNVector3(0, 1.6 as CGFloat, 0)
        parent.addChildNode(headN)
        // Horns
        for s: CGFloat in [-1, 1] {
            let horn = SCNCone(topRadius: 0.0, bottomRadius: 0.04, height: 0.3)
            let hornMat = SCNMaterial(); hornMat.diffuse.contents = rgb(0.2, 0.1, 0.1)
            horn.materials = [hornMat]
            let hornN = SCNNode(geometry: horn)
            hornN.position = SCNVector3(s * 0.15 as CGFloat, 1.85 as CGFloat, 0)
            hornN.eulerAngles = SCNVector3(0, 0, s * CGFloat.pi / 6)
            parent.addChildNode(hornN)
        }
        // Glowing eyes
        for s: CGFloat in [-0.06, 0.06] {
            let eye = SCNSphere(radius: 0.035)
            let eyeMat = SCNMaterial()
            eyeMat.diffuse.contents = rgb(0.0, 0.9, 0.3)
            eyeMat.emission.contents = rgb(0.0, 0.8, 0.2)
            eye.materials = [eyeMat]
            let eyeN = SCNNode(geometry: eye)
            eyeN.position = SCNVector3(s as CGFloat, 1.63 as CGFloat, -0.18 as CGFloat)
            parent.addChildNode(eyeN)
        }
        // Eldritch tome (held in left)
        let tome = SCNBox(width: 0.2, height: 0.25, length: 0.08, chamferRadius: 0.02)
        let tomeMat = SCNMaterial(); tomeMat.diffuse.contents = rgb(0.3, 0.05, 0.15)
        tomeMat.emission.contents = rgb(0.1, 0.0, 0.05)
        tome.materials = [tomeMat]
        let tomeN = SCNNode(geometry: tome)
        tomeN.position = SCNVector3(-0.4 as CGFloat, 0.9 as CGFloat, 0)
        parent.addChildNode(tomeN)
        // Eldritch orb (right hand, green glow)
        let orb = SCNSphere(radius: 0.12)
        let orbMat = SCNMaterial()
        orbMat.diffuse.contents = rgb(0.0, 0.8, 0.3)
        orbMat.emission.contents = rgb(0.0, 0.6, 0.2)
        orb.materials = [orbMat]
        let orbN = SCNNode(geometry: orb)
        orbN.position = SCNVector3(0.4 as CGFloat, 1.1 as CGFloat, 0)
        parent.addChildNode(orbN)
    }
    return parent
}

// MARK: - Monster Model Builders
func buildMonsterModel(type: MonsterType) -> SCNNode {
    let parent = SCNNode()
    switch type {
    case .giantRat:
        let body = SCNBox(width: 0.5, height: 0.3, length: 0.8, chamferRadius: 0.1)
        let bMat = SCNMaterial(); bMat.diffuse.contents = rgb(0.35, 0.25, 0.15)
        body.materials = [bMat]
        let bN = SCNNode(geometry: body); bN.position = SCNVector3(0, 0.25 as CGFloat, 0)
        parent.addChildNode(bN)
        let head = SCNSphere(radius: 0.15)
        let hMat = SCNMaterial(); hMat.diffuse.contents = rgb(0.4, 0.3, 0.2)
        head.materials = [hMat]
        let hN = SCNNode(geometry: head); hN.position = SCNVector3(0, 0.3 as CGFloat, 0.45 as CGFloat)
        parent.addChildNode(hN)
    case .goblin:
        let body = SCNBox(width: 0.5, height: 0.7, length: 0.4, chamferRadius: 0.05)
        let bMat = SCNMaterial(); bMat.diffuse.contents = rgb(0.2, 0.45, 0.15)
        body.materials = [bMat]
        let bN = SCNNode(geometry: body); bN.position = SCNVector3(0, 0.55 as CGFloat, 0)
        parent.addChildNode(bN)
        let head = SCNSphere(radius: 0.2)
        let hMat = SCNMaterial(); hMat.diffuse.contents = rgb(0.25, 0.5, 0.2)
        head.materials = [hMat]
        let hN = SCNNode(geometry: head); hN.position = SCNVector3(0, 1.1 as CGFloat, 0)
        parent.addChildNode(hN)
    case .skeleton:
        let body = SCNCylinder(radius: 0.15, height: 1.0)
        let bMat = SCNMaterial(); bMat.diffuse.contents = rgb(0.85, 0.82, 0.75)
        body.materials = [bMat]
        let bN = SCNNode(geometry: body); bN.position = SCNVector3(0, 0.7 as CGFloat, 0)
        parent.addChildNode(bN)
        let head = SCNSphere(radius: 0.2)
        let hMat = SCNMaterial(); hMat.diffuse.contents = rgb(0.9, 0.87, 0.8)
        head.materials = [hMat]
        let hN = SCNNode(geometry: head); hN.position = SCNVector3(0, 1.4 as CGFloat, 0)
        parent.addChildNode(hN)
        let eyeL = SCNSphere(radius: 0.04)
        let eMat = SCNMaterial(); eMat.diffuse.contents = NSColor.black
        eMat.emission.contents = rgb(0.6, 0.0, 0.0)
        eyeL.materials = [eMat]
        let eN = SCNNode(geometry: eyeL); eN.position = SCNVector3(-0.07 as CGFloat, 1.44 as CGFloat, 0.17 as CGFloat)
        parent.addChildNode(eN)
        let eyeR = SCNNode(geometry: eyeL)
        eyeR.position = SCNVector3(0.07 as CGFloat, 1.44 as CGFloat, 0.17 as CGFloat)
        parent.addChildNode(eyeR)
    case .orc:
        let body = SCNBox(width: 0.8, height: 0.9, length: 0.5, chamferRadius: 0.05)
        let bMat = SCNMaterial(); bMat.diffuse.contents = rgb(0.3, 0.4, 0.2)
        body.materials = [bMat]
        let bN = SCNNode(geometry: body); bN.position = SCNVector3(0, 0.7 as CGFloat, 0)
        parent.addChildNode(bN)
        let head = SCNSphere(radius: 0.25)
        let hMat = SCNMaterial(); hMat.diffuse.contents = rgb(0.35, 0.45, 0.25)
        head.materials = [hMat]
        let hN = SCNNode(geometry: head); hN.position = SCNVector3(0, 1.4 as CGFloat, 0)
        parent.addChildNode(hN)
    case .ogre:
        let body = SCNBox(width: 1.0, height: 1.2, length: 0.7, chamferRadius: 0.1)
        let bMat = SCNMaterial(); bMat.diffuse.contents = rgb(0.45, 0.35, 0.25)
        body.materials = [bMat]
        let bN = SCNNode(geometry: body); bN.position = SCNVector3(0, 0.9 as CGFloat, 0)
        parent.addChildNode(bN)
        let head = SCNSphere(radius: 0.3)
        let hMat = SCNMaterial(); hMat.diffuse.contents = rgb(0.5, 0.4, 0.3)
        head.materials = [hMat]
        let hN = SCNNode(geometry: head); hN.position = SCNVector3(0, 1.8 as CGFloat, 0)
        parent.addChildNode(hN)
        let club = SCNCylinder(radius: 0.08, height: 1.3)
        let cMat = SCNMaterial(); cMat.diffuse.contents = rgb(0.35, 0.2, 0.1)
        club.materials = [cMat]
        let cN = SCNNode(geometry: club)
        cN.position = SCNVector3(0.7 as CGFloat, 0.9 as CGFloat, 0)
        cN.eulerAngles = SCNVector3(0, 0, CGFloat.pi / 5)
        parent.addChildNode(cN)
    case .youngDragon:
        let body = SCNBox(width: 1.2, height: 0.8, length: 1.5, chamferRadius: 0.15)
        let bMat = SCNMaterial(); bMat.diffuse.contents = rgb(0.6, 0.15, 0.1)
        body.materials = [bMat]
        let bN = SCNNode(geometry: body); bN.position = SCNVector3(0, 0.8 as CGFloat, 0)
        parent.addChildNode(bN)
        let head = SCNBox(width: 0.5, height: 0.4, length: 0.7, chamferRadius: 0.1)
        let hMat = SCNMaterial(); hMat.diffuse.contents = rgb(0.65, 0.2, 0.12)
        head.materials = [hMat]
        let hN = SCNNode(geometry: head); hN.position = SCNVector3(0, 1.2 as CGFloat, 0.8 as CGFloat)
        parent.addChildNode(hN)
        // Wings
        let wing = SCNBox(width: 1.0, height: 0.05, length: 0.6, chamferRadius: 0)
        let wMat = SCNMaterial(); wMat.diffuse.contents = rgb(0.55, 0.1, 0.08)
        wing.materials = [wMat]
        let wL = SCNNode(geometry: wing)
        wL.position = SCNVector3(-0.8 as CGFloat, 1.2 as CGFloat, 0)
        wL.eulerAngles = SCNVector3(0, 0, -CGFloat.pi / 6)
        parent.addChildNode(wL)
        let wR = SCNNode(geometry: wing)
        wR.position = SCNVector3(0.8 as CGFloat, 1.2 as CGFloat, 0)
        wR.eulerAngles = SCNVector3(0, 0, CGFloat.pi / 6)
        parent.addChildNode(wR)
        // Eyes glow
        let eye = SCNSphere(radius: 0.06)
        let eyeMat = SCNMaterial()
        eyeMat.diffuse.contents = rgb(1.0, 0.8, 0.0)
        eyeMat.emission.contents = rgb(0.8, 0.5, 0.0)
        eye.materials = [eyeMat]
        let eL = SCNNode(geometry: eye)
        eL.position = SCNVector3(-0.15 as CGFloat, 1.3 as CGFloat, 1.1 as CGFloat)
        parent.addChildNode(eL)
        let eR = SCNNode(geometry: eye)
        eR.position = SCNVector3(0.15 as CGFloat, 1.3 as CGFloat, 1.1 as CGFloat)
        parent.addChildNode(eR)
    }
    return parent
}

// MARK: - Torch Builder
func buildTorch(x: Int, y: Int) -> SCNNode {
    let tileSize: CGFloat = 2.0
    let parent = SCNNode()
    let stick = SCNCylinder(radius: 0.04, height: 0.6)
    let sMat = SCNMaterial(); sMat.diffuse.contents = rgb(0.35, 0.2, 0.1)
    stick.materials = [sMat]
    let sN = SCNNode(geometry: stick); sN.position = SCNVector3(0, 2.0 as CGFloat, 0)
    parent.addChildNode(sN)
    let flame = SCNSphere(radius: 0.12)
    let fMat = SCNMaterial()
    fMat.diffuse.contents = rgb(1.0, 0.6, 0.1)
    fMat.emission.contents = rgb(1.0, 0.5, 0.0)
    flame.materials = [fMat]
    let fN = SCNNode(geometry: flame); fN.position = SCNVector3(0, 2.4 as CGFloat, 0)
    parent.addChildNode(fN)
    let light = SCNLight()
    light.type = .omni
    light.color = rgb(1.0, 0.7, 0.3)
    light.intensity = 300
    light.attenuationStartDistance = 2
    light.attenuationEndDistance = 10
    fN.light = light
    parent.position = SCNVector3(CGFloat(x) * tileSize, 0 as CGFloat, CGFloat(y) * tileSize)
    return parent
}

// MARK: - Game Controller
class GameController: NSObject, SCNSceneRendererDelegate {
    let tileSize: CGFloat = 2.0
    var scnView: SCNView!
    var scene: SCNScene!
    var cameraNode: SCNNode!
    var hudScene: SKScene!
    var dungeon = Dungeon()
    var player: PlayerCharacter?
    var monsters: [Monster] = []
    var currentFloor: Int = 1
    var gameState: GameState = .classSelect
    var dungeonNode: SCNNode!
    var moveHighlights: [SCNNode] = []
    var combatLog: [String] = []
    var enemyActionIndex: Int = 0

    // HUD labels
    var classLabel: SKLabelNode!
    var hpLabel: SKLabelNode!
    var hpBar: SKShapeNode!
    var hpBarBg: SKShapeNode!
    var acLabel: SKLabelNode!
    var statsLabel: SKLabelNode!
    var floorLabel: SKLabelNode!
    var turnLabel: SKLabelNode!
    var xpLabel: SKLabelNode!
    var goldLabel: SKLabelNode!
    var killLabel: SKLabelNode!
    var actionLabel: SKLabelNode!
    var diceLabel: SKLabelNode!
    var diceDetailLabel: SKLabelNode!
    var diceResultLabel: SKLabelNode!
    var logLabels: [SKLabelNode] = []
    var classButtons: [SKShapeNode] = []
    var classButtonLabels: [SKLabelNode] = []
    var levelUpLabel: SKLabelNode!
    var deathLabel: SKLabelNode!
    var minimapNode: SKShapeNode!

    func setup(view: SCNView) {
        scnView = view
        scene = SCNScene()
        scnView.scene = scene
        scnView.delegate = self
        scnView.backgroundColor = NSColor.black
        scnView.allowsCameraControl = false
        scnView.showsStatistics = false

        // Camera
        cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera!.zNear = 1
        cameraNode.camera!.zFar = 100
        cameraNode.camera!.fieldOfView = 50
        cameraNode.camera!.wantsHDR = true
        cameraNode.camera!.bloomIntensity = 0.5
        cameraNode.camera!.bloomThreshold = 0.8
        cameraNode.position = SCNVector3(0, 22 as CGFloat, 10 as CGFloat)
        cameraNode.eulerAngles = SCNVector3(-CGFloat.pi / 2.5, 0, 0)
        scene.rootNode.addChildNode(cameraNode)

        // Fog
        scene.fogStartDistance = 12
        scene.fogEndDistance = 30
        scene.fogColor = NSColor.black
        scene.fogDensityExponent = 1.5

        // Ambient light
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light!.type = .ambient
        ambient.light!.color = rgb(0.08, 0.08, 0.12)
        ambient.light!.intensity = 200
        scene.rootNode.addChildNode(ambient)

        // HUD
        hudScene = SKScene(size: CGSize(width: 1280, height: 720))
        hudScene.isUserInteractionEnabled = false
        scnView.overlaySKScene = hudScene

        setupHUD()
        showClassSelect()
    }

    func setupHUD() {
        // Top Left - Character Panel
        classLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        classLabel.fontSize = 16; classLabel.fontColor = .white
        classLabel.position = CGPoint(x: 20, y: 690)
        classLabel.horizontalAlignmentMode = .left
        hudScene.addChild(classLabel)

        hpBarBg = SKShapeNode(rect: CGRect(x: 20, y: 662, width: 200, height: 16))
        hpBarBg.fillColor = SKColor(red: 0.2, green: 0.0, blue: 0.0, alpha: 0.8)
        hpBarBg.strokeColor = SKColor.gray
        hudScene.addChild(hpBarBg)

        hpBar = SKShapeNode(rect: CGRect(x: 20, y: 662, width: 200, height: 16))
        hpBar.fillColor = SKColor.green
        hpBar.strokeColor = .clear
        hudScene.addChild(hpBar)

        hpLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        hpLabel.fontSize = 12; hpLabel.fontColor = .white
        hpLabel.position = CGPoint(x: 120, y: 665)
        hpLabel.horizontalAlignmentMode = .center
        hudScene.addChild(hpLabel)

        acLabel = SKLabelNode(fontNamed: "Menlo")
        acLabel.fontSize = 14; acLabel.fontColor = SKColor(red: 0.7, green: 0.7, blue: 1.0, alpha: 1)
        acLabel.position = CGPoint(x: 20, y: 642)
        acLabel.horizontalAlignmentMode = .left
        hudScene.addChild(acLabel)

        statsLabel = SKLabelNode(fontNamed: "Menlo")
        statsLabel.fontSize = 10; statsLabel.fontColor = SKColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1)
        statsLabel.position = CGPoint(x: 20, y: 622)
        statsLabel.horizontalAlignmentMode = .left
        hudScene.addChild(statsLabel)

        // Top Center
        floorLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        floorLabel.fontSize = 18; floorLabel.fontColor = .white
        floorLabel.position = CGPoint(x: 640, y: 692)
        floorLabel.horizontalAlignmentMode = .center
        hudScene.addChild(floorLabel)

        turnLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        turnLabel.fontSize = 16
        turnLabel.position = CGPoint(x: 640, y: 668)
        turnLabel.horizontalAlignmentMode = .center
        hudScene.addChild(turnLabel)

        // Top Right
        xpLabel = SKLabelNode(fontNamed: "Menlo")
        xpLabel.fontSize = 13; xpLabel.fontColor = SKColor(red: 0.6, green: 0.8, blue: 1.0, alpha: 1)
        xpLabel.position = CGPoint(x: 1260, y: 695)
        xpLabel.horizontalAlignmentMode = .right
        hudScene.addChild(xpLabel)

        goldLabel = SKLabelNode(fontNamed: "Menlo")
        goldLabel.fontSize = 13; goldLabel.fontColor = SKColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 1)
        goldLabel.position = CGPoint(x: 1260, y: 675)
        goldLabel.horizontalAlignmentMode = .right
        hudScene.addChild(goldLabel)

        killLabel = SKLabelNode(fontNamed: "Menlo")
        killLabel.fontSize = 13; killLabel.fontColor = SKColor(red: 1.0, green: 0.4, blue: 0.3, alpha: 1)
        killLabel.position = CGPoint(x: 1260, y: 655)
        killLabel.horizontalAlignmentMode = .right
        hudScene.addChild(killLabel)

        // Bottom - Combat Log background
        let logBg = SKShapeNode(rect: CGRect(x: 0, y: 0, width: 1280, height: 90))
        logBg.fillColor = SKColor(red: 0, green: 0, blue: 0, alpha: 0.7)
        logBg.strokeColor = .clear; logBg.zPosition = 5
        hudScene.addChild(logBg)

        for i in 0..<5 {
            let lbl = SKLabelNode(fontNamed: "Menlo")
            lbl.fontSize = 11; lbl.fontColor = .white
            lbl.position = CGPoint(x: 10, y: 70 - i * 15)
            lbl.horizontalAlignmentMode = .left; lbl.zPosition = 6
            hudScene.addChild(lbl)
            logLabels.append(lbl)
        }

        // Action bar
        actionLabel = SKLabelNode(fontNamed: "Menlo")
        actionLabel.fontSize = 13; actionLabel.fontColor = SKColor(red: 0.8, green: 0.8, blue: 0.6, alpha: 1)
        actionLabel.position = CGPoint(x: 640, y: 98)
        actionLabel.horizontalAlignmentMode = .center; actionLabel.zPosition = 6
        hudScene.addChild(actionLabel)

        // Dice display (center, hidden by default)
        diceLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        diceLabel.fontSize = 72; diceLabel.fontColor = .white
        diceLabel.position = CGPoint(x: 640, y: 400)
        diceLabel.horizontalAlignmentMode = .center; diceLabel.zPosition = 20
        diceLabel.alpha = 0
        hudScene.addChild(diceLabel)

        diceDetailLabel = SKLabelNode(fontNamed: "Menlo")
        diceDetailLabel.fontSize = 18; diceDetailLabel.fontColor = .white
        diceDetailLabel.position = CGPoint(x: 640, y: 365)
        diceDetailLabel.horizontalAlignmentMode = .center; diceDetailLabel.zPosition = 20
        diceDetailLabel.alpha = 0
        hudScene.addChild(diceDetailLabel)

        diceResultLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        diceResultLabel.fontSize = 36
        diceResultLabel.position = CGPoint(x: 640, y: 320)
        diceResultLabel.horizontalAlignmentMode = .center; diceResultLabel.zPosition = 20
        diceResultLabel.alpha = 0
        hudScene.addChild(diceResultLabel)

        // Level up label
        levelUpLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        levelUpLabel.fontSize = 48; levelUpLabel.fontColor = SKColor(red: 1.0, green: 0.85, blue: 0.0, alpha: 1)
        levelUpLabel.position = CGPoint(x: 640, y: 400)
        levelUpLabel.horizontalAlignmentMode = .center; levelUpLabel.zPosition = 25
        levelUpLabel.alpha = 0; levelUpLabel.text = "LEVEL UP!"
        hudScene.addChild(levelUpLabel)

        // Death label
        deathLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        deathLabel.fontSize = 48; deathLabel.fontColor = SKColor.red
        deathLabel.position = CGPoint(x: 640, y: 400)
        deathLabel.horizontalAlignmentMode = .center; deathLabel.zPosition = 25
        deathLabel.alpha = 0
        hudScene.addChild(deathLabel)

        // Minimap
        minimapNode = SKShapeNode(rect: CGRect(x: 1130, y: 100, width: 140, height: 140))
        minimapNode.fillColor = SKColor(red: 0, green: 0, blue: 0, alpha: 0.6)
        minimapNode.strokeColor = SKColor.gray; minimapNode.zPosition = 10
        hudScene.addChild(minimapNode)
    }

    func showClassSelect() {
        gameState = .classSelect
        // Hide gameplay HUD
        classLabel.text = ""; hpLabel.text = ""; acLabel.text = ""; statsLabel.text = ""
        floorLabel.text = ""; turnLabel.text = ""; xpLabel.text = ""; goldLabel.text = ""
        killLabel.text = ""; actionLabel.text = ""

        // Clear old buttons
        for b in classButtons { b.removeFromParent() }
        for l in classButtonLabels { l.removeFromParent() }
        classButtons.removeAll(); classButtonLabels.removeAll()

        let title = SKLabelNode(fontNamed: "Menlo-Bold")
        title.fontSize = 36; title.fontColor = SKColor(red: 0.9, green: 0.75, blue: 0.2, alpha: 1)
        title.position = CGPoint(x: 640, y: 580); title.horizontalAlignmentMode = .center
        title.zPosition = 30; title.text = "DUNGEONS & DICE"; title.name = "titleLabel"
        hudScene.addChild(title)

        let sub = SKLabelNode(fontNamed: "Menlo")
        sub.fontSize = 16; sub.fontColor = .white
        sub.position = CGPoint(x: 640, y: 545); sub.horizontalAlignmentMode = .center
        sub.zPosition = 30; sub.text = "Choose your class (click or press 1-5):"; sub.name = "subLabel"
        hudScene.addChild(sub)

        let classes: [(CharacterClass, String, String)] = [
            (.fighter, "1. FIGHTER", "HP 12+CON, AC 16, d8 sword"),
            (.rogue, "2. ROGUE", "HP 8+CON, AC 14, d6 dagger + sneak"),
            (.cleric, "3. CLERIC", "HP 10+CON, AC 16, d6 mace + heals"),
            (.wizard, "4. WIZARD", "HP 6+CON, AC 12, d4 dagger + spells"),
            (.warlock, "5. WARLOCK", "HP 8+CON, AC 13, d10 blast + hex")
        ]

        for (i, (_, name, desc)) in classes.enumerated() {
            let bx = CGFloat(128 + i * 206)
            let btn = SKShapeNode(rect: CGRect(x: bx - 95, y: 350, width: 190, height: 120), cornerRadius: 8)
            btn.fillColor = SKColor(red: 0.15, green: 0.15, blue: 0.2, alpha: 0.9)
            btn.strokeColor = SKColor(red: 0.5, green: 0.4, blue: 0.2, alpha: 1)
            btn.lineWidth = 2; btn.zPosition = 30; btn.name = "classBtn_\(i)"
            hudScene.addChild(btn); classButtons.append(btn)

            let nameLbl = SKLabelNode(fontNamed: "Menlo-Bold")
            nameLbl.fontSize = 16; nameLbl.fontColor = SKColor(red: 0.9, green: 0.8, blue: 0.3, alpha: 1)
            nameLbl.position = CGPoint(x: bx, y: 435); nameLbl.horizontalAlignmentMode = .center
            nameLbl.zPosition = 31; nameLbl.text = name
            hudScene.addChild(nameLbl); classButtonLabels.append(nameLbl)

            let descLbl = SKLabelNode(fontNamed: "Menlo")
            descLbl.fontSize = 10; descLbl.fontColor = .white
            descLbl.position = CGPoint(x: bx, y: 370); descLbl.horizontalAlignmentMode = .center
            descLbl.zPosition = 31; descLbl.text = desc
            hudScene.addChild(descLbl); classButtonLabels.append(descLbl)
        }
    }

    func hideClassSelect() {
        for b in classButtons { b.removeFromParent() }
        for l in classButtonLabels { l.removeFromParent() }
        classButtons.removeAll(); classButtonLabels.removeAll()
        hudScene.childNode(withName: "titleLabel")?.removeFromParent()
        hudScene.childNode(withName: "subLabel")?.removeFromParent()
    }

    func selectClass(_ cls: CharacterClass) {
        hideClassSelect()
        player = PlayerCharacter(cls: cls)
        currentFloor = 1
        combatLog.removeAll()
        addLog("A brave \(cls.rawValue) enters the dungeon...")
        startFloor()
    }

    func startFloor() {
        // Clean scene
        if dungeonNode != nil { dungeonNode.removeFromParentNode() }
        dungeonNode = SCNNode()
        scene.rootNode.addChildNode(dungeonNode)
        monsters.removeAll()
        clearHighlights()

        // Generate dungeon
        dungeon = Dungeon()
        dungeon.generate(floor: currentFloor)

        guard let p = player else { return }
        p.gridX = dungeon.spawnX; p.gridY = dungeon.spawnY
        p.refreshFloor()

        // Build tiles
        for y in 0..<Dungeon.size {
            for x in 0..<Dungeon.size {
                let tile = dungeon.tiles[y][x]
                if tile != .wall {
                    let floorNode = buildFloorTile(x: x, y: y, type: tile)
                    dungeonNode.addChildNode(floorNode)
                    if tile == .chest {
                        dungeonNode.addChildNode(buildChest(x: x, y: y))
                    }
                    if tile == .stairs {
                        dungeonNode.addChildNode(buildStairsModel(x: x, y: y))
                    }
                }
            }
        }

        // Build walls adjacent to floor
        for y in 0..<Dungeon.size {
            for x in 0..<Dungeon.size {
                if dungeon.tiles[y][x] == .wall {
                    var adjFloor = false
                    for dy in -1...1 {
                        for dx in -1...1 {
                            let nx = x + dx; let ny = y + dy
                            if nx >= 0 && ny >= 0 && nx < Dungeon.size && ny < Dungeon.size {
                                if dungeon.tiles[ny][nx] != .wall { adjFloor = true }
                            }
                        }
                    }
                    if adjFloor {
                        dungeonNode.addChildNode(buildWall(x: x, y: y))
                    }
                }
            }
        }

        // Place torches in rooms
        for room in dungeon.rooms {
            let tx = room.x; let ty = room.y
            dungeonNode.addChildNode(buildTorch(x: tx, y: ty))
            if room.w > 4 {
                dungeonNode.addChildNode(buildTorch(x: room.x + room.w - 1, y: room.y + room.h - 1))
            }
        }

        // Player model
        let pModel = buildPlayerModel(cls: p.cls)
        pModel.position = SCNVector3(CGFloat(p.gridX) * tileSize, 0 as CGFloat, CGFloat(p.gridY) * tileSize)
        pModel.name = "player"
        dungeonNode.addChildNode(pModel)
        p.node = pModel

        // Player point light
        let pLight = SCNNode()
        pLight.light = SCNLight()
        pLight.light!.type = .omni
        pLight.light!.color = rgb(0.9, 0.8, 0.6)
        pLight.light!.intensity = 400
        pLight.light!.attenuationStartDistance = 3
        pLight.light!.attenuationEndDistance = 14
        pLight.position = SCNVector3(0, 3 as CGFloat, 0)
        pLight.name = "playerLight"
        pModel.addChildNode(pLight)

        // Spawn monsters
        spawnMonsters()

        // Reveal around spawn
        dungeon.revealAround(p.gridX, p.gridY)

        // Start player turn
        gameState = .playerTurn
        p.startTurn()
        updateHUD()
        updateCamera(immediate: true)
        showMovementHighlights()
    }

    func spawnMonsters() {
        guard let p = player else { return }
        let monsterTypes: [(MonsterType, Int)] = [
            (.giantRat, 1), (.goblin, 1), (.skeleton, 2),
            (.orc, 3), (.ogre, 5), (.youngDragon, 8)
        ]
        let available = monsterTypes.filter { $0.1 <= currentFloor }
        let count = min(3 + currentFloor, 12)
        for room in dungeon.rooms {
            if room.centerX == dungeon.spawnX && room.centerY == dungeon.spawnY { continue }
            let numInRoom = Int.random(in: 1...min(count / dungeon.rooms.count + 1, 3))
            for _ in 0..<numInRoom {
                let mx = Int.random(in: room.x + 1..<room.x + room.w - 1)
                let my = Int.random(in: room.y + 1..<room.y + room.h - 1)
                if mx == dungeon.stairsX && my == dungeon.stairsY { continue }
                if mx == p.gridX && my == p.gridY { continue }
                if monsters.contains(where: { $0.gridX == mx && $0.gridY == my }) { continue }
                let typeInfo = available.randomElement()!
                let m = Monster(type: typeInfo.0, x: mx, y: my)
                let mModel = buildMonsterModel(type: m.type)
                mModel.position = SCNVector3(CGFloat(mx) * tileSize, 0 as CGFloat, CGFloat(my) * tileSize)
                mModel.name = "monster_\(monsters.count)"
                dungeonNode.addChildNode(mModel)
                m.node = mModel
                monsters.append(m)
            }
        }
    }

    // MARK: - HUD Updates
    func updateHUD() {
        guard let p = player else { return }
        classLabel.text = "\(p.cls.rawValue) LV \(p.level)"
        hpLabel.text = "HP: \(p.hp)/\(p.maxHP)"
        acLabel.text = "AC: \(p.ac)"
        statsLabel.text = "STR \(p.scores.str) DEX \(p.scores.dex) CON \(p.scores.con) INT \(p.scores.intel) WIS \(p.scores.wis) CHA \(p.scores.cha)"
        floorLabel.text = "FLOOR \(currentFloor)"
        let nextXP = p.level <= 6 ? PlayerCharacter.xpThresholds[p.level - 1] : 9999
        xpLabel.text = "XP: \(p.xp)/\(nextXP)"
        goldLabel.text = "Gold: \(p.gold)"
        killLabel.text = "Kills: \(p.kills)"

        // HP bar
        let frac = CGFloat(max(0, p.hp)) / CGFloat(max(1, p.maxHP))
        hpBar.removeFromParent()
        hpBar = SKShapeNode(rect: CGRect(x: 20, y: 662, width: 200.0 * frac, height: 16))
        if frac > 0.5 { hpBar.fillColor = SKColor.green }
        else if frac > 0.25 { hpBar.fillColor = SKColor(red: 0.9, green: 0.7, blue: 0.0, alpha: 1) }
        else { hpBar.fillColor = SKColor.red }
        hpBar.strokeColor = .clear
        hudScene.addChild(hpBar)

        // Turn indicator
        if gameState == .playerTurn {
            turnLabel.text = "YOUR TURN"
            turnLabel.fontColor = SKColor(red: 0.2, green: 0.9, blue: 0.9, alpha: 1)
        } else if gameState == .enemyTurn {
            turnLabel.text = "ENEMY TURN"
            turnLabel.fontColor = SKColor.red
        } else {
            turnLabel.text = ""
        }

        // Action bar
        if gameState == .playerTurn {
            let a1u = p.ability1Uses > 10 ? "∞" : "\(p.ability1Uses)"
            let a2u = p.ability2Uses > 10 ? "∞" : "\(p.ability2Uses)"
            actionLabel.text = "[Click] Move/Attack  [1] \(p.ability1Name)(\(a1u))  [2] \(p.ability2Name)(\(a2u))  [Space] End Turn"
        } else {
            actionLabel.text = ""
        }

        // Combat log
        for i in 0..<5 {
            let idx = combatLog.count - 5 + i
            if idx >= 0 && idx < combatLog.count {
                logLabels[i].text = combatLog[idx]
            } else {
                logLabels[i].text = ""
            }
        }

        updateMinimap()
    }

    func updateMinimap() {
        // Remove old minimap dots
        minimapNode.removeAllChildren()
        guard let p = player else { return }
        let scale: CGFloat = 140.0 / CGFloat(Dungeon.size)
        let ox: CGFloat = 1130; let oy: CGFloat = 100
        for y in 0..<Dungeon.size {
            for x in 0..<Dungeon.size {
                if dungeon.explored[y][x] && dungeon.tiles[y][x] != .wall {
                    let dot = SKShapeNode(rect: CGRect(x: ox + CGFloat(x) * scale,
                                                       y: oy + CGFloat(Dungeon.size - 1 - y) * scale,
                                                       width: scale, height: scale))
                    dot.fillColor = SKColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 0.8)
                    dot.strokeColor = .clear; dot.zPosition = 11
                    minimapNode.addChild(dot)
                }
            }
        }
        // Player dot
        let pd = SKShapeNode(circleOfRadius: 3)
        pd.fillColor = SKColor.cyan; pd.strokeColor = .clear; pd.zPosition = 13
        pd.position = CGPoint(x: ox + CGFloat(p.gridX) * scale + scale / 2,
                              y: oy + CGFloat(Dungeon.size - 1 - p.gridY) * scale + scale / 2)
        minimapNode.addChild(pd)
        // Enemy dots
        for m in monsters {
            if dungeon.explored[m.gridY][m.gridX] {
                let ed = SKShapeNode(circleOfRadius: 2)
                ed.fillColor = SKColor.red; ed.strokeColor = .clear; ed.zPosition = 12
                ed.position = CGPoint(x: ox + CGFloat(m.gridX) * scale + scale / 2,
                                      y: oy + CGFloat(Dungeon.size - 1 - m.gridY) * scale + scale / 2)
                minimapNode.addChild(ed)
            }
        }
        // Stairs dot
        if dungeon.explored[dungeon.stairsY][dungeon.stairsX] {
            let sd = SKShapeNode(circleOfRadius: 3)
            sd.fillColor = SKColor.yellow; sd.strokeColor = .clear; sd.zPosition = 12
            sd.position = CGPoint(x: ox + CGFloat(dungeon.stairsX) * scale + scale / 2,
                                  y: oy + CGFloat(Dungeon.size - 1 - dungeon.stairsY) * scale + scale / 2)
            minimapNode.addChild(sd)
        }
    }

    func addLog(_ msg: String) {
        combatLog.append(msg)
        if combatLog.count > 50 { combatLog.removeFirst() }
    }

    // MARK: - Camera
    func updateCamera(immediate: Bool = false) {
        guard let p = player else { return }
        let tx = CGFloat(p.gridX) * tileSize
        let tz = CGFloat(p.gridY) * tileSize
        let target = SCNVector3(tx, 22 as CGFloat, tz + 10 as CGFloat)
        if immediate {
            cameraNode.position = target
        } else {
            let cur = cameraNode.position
            let lerp: CGFloat = 0.12
            cameraNode.position = SCNVector3(
                cur.x + (target.x - cur.x) * lerp,
                cur.y + (target.y - cur.y) * lerp,
                cur.z + (target.z - cur.z) * lerp
            )
        }
    }

    // MARK: - Movement Highlights
    func showMovementHighlights() {
        clearHighlights()
        guard let p = player, gameState == .playerTurn else { return }
        let reachable = getReachableTiles(fromX: p.gridX, fromY: p.gridY, range: p.movementLeft)
        for (x, y) in reachable {
            if x == p.gridX && y == p.gridY { continue }
            let plane = SCNPlane(width: tileSize * 0.9, height: tileSize * 0.9)
            let mat = SCNMaterial()
            mat.diffuse.contents = NSColor(red: 0.0, green: 0.8, blue: 0.8, alpha: 0.25)
            mat.isDoubleSided = true
            plane.materials = [mat]
            let node = SCNNode(geometry: plane)
            node.eulerAngles = SCNVector3(-CGFloat.pi / 2, 0, 0)
            node.position = SCNVector3(CGFloat(x) * tileSize, 0.12 as CGFloat, CGFloat(y) * tileSize)
            node.name = "highlight"
            dungeonNode.addChildNode(node)
            moveHighlights.append(node)
        }
    }

    func clearHighlights() {
        for h in moveHighlights { h.removeFromParentNode() }
        moveHighlights.removeAll()
    }

    func getReachableTiles(fromX: Int, fromY: Int, range: Int) -> [(Int, Int)] {
        var result: [(Int, Int)] = []
        for dy in -range...range {
            for dx in -range...range {
                let dist = abs(dx) + abs(dy)
                if dist > range || dist == 0 { continue }
                let nx = fromX + dx; let ny = fromY + dy
                if dungeon.isWalkable(nx, ny) {
                    let occupied = monsters.contains { $0.gridX == nx && $0.gridY == ny && $0.hp > 0 }
                    if !occupied { result.append((nx, ny)) }
                }
            }
        }
        return result
    }

    // MARK: - Dice Display
    func showDiceRoll(roll: Int, mod: Int, total: Int, targetAC: Int, hit: Bool, isCrit: Bool) {
        diceLabel.text = "\(roll)"
        diceLabel.alpha = 1.0
        diceDetailLabel.text = "d20(\(roll)) + \(mod) = \(total) vs AC \(targetAC)"
        diceDetailLabel.alpha = 1.0
        if isCrit {
            diceResultLabel.text = "CRITICAL HIT!"
            diceResultLabel.fontColor = SKColor(red: 1.0, green: 0.85, blue: 0.0, alpha: 1)
        } else if hit {
            diceResultLabel.text = "HIT!"
            diceResultLabel.fontColor = SKColor.green
        } else {
            diceResultLabel.text = "MISS!"
            diceResultLabel.fontColor = SKColor.red
        }
        diceResultLabel.alpha = 1.0

        let fadeOut = SKAction.sequence([
            SKAction.wait(forDuration: 1.5),
            SKAction.fadeOut(withDuration: 0.5)
        ])
        diceLabel.run(fadeOut)
        diceDetailLabel.run(fadeOut)
        diceResultLabel.run(fadeOut)
    }

    func showDamage(amount: Int, desc: String) {
        let dmgLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        dmgLabel.fontSize = 24
        dmgLabel.fontColor = SKColor(red: 1.0, green: 0.3, blue: 0.2, alpha: 1)
        dmgLabel.text = "\(amount) damage!"
        dmgLabel.position = CGPoint(x: 640, y: 285)
        dmgLabel.horizontalAlignmentMode = .center; dmgLabel.zPosition = 20
        hudScene.addChild(dmgLabel)
        let seq = SKAction.sequence([
            SKAction.group([
                SKAction.moveBy(x: 0, y: 30, duration: 1.2),
                SKAction.fadeOut(withDuration: 1.2)
            ]),
            SKAction.removeFromParent()
        ])
        dmgLabel.run(seq)
    }

    // MARK: - Floating Damage Numbers in 3D
    func showFloatingDamage(_ amount: Int, at pos: SCNVector3) {
        // We use SpriteKit overlay for simplicity
        let screenPos = scnView.projectPoint(SCNVector3(pos.x, pos.y + 2.5, pos.z))
        let lbl = SKLabelNode(fontNamed: "Menlo-Bold")
        lbl.fontSize = 22
        lbl.fontColor = SKColor(red: 1.0, green: 0.2, blue: 0.1, alpha: 1)
        lbl.text = "-\(amount)"
        lbl.position = CGPoint(x: CGFloat(screenPos.x), y: CGFloat(screenPos.y))
        lbl.horizontalAlignmentMode = .center; lbl.zPosition = 30
        hudScene.addChild(lbl)
        let seq = SKAction.sequence([
            SKAction.group([
                SKAction.moveBy(x: 0, y: 40, duration: 1.0),
                SKAction.fadeOut(withDuration: 1.0)
            ]),
            SKAction.removeFromParent()
        ])
        lbl.run(seq)
    }

    // MARK: - Screen Shake
    func screenShake() {
        let shakeAmount: CGFloat = 0.4
        let seq = SCNAction.sequence([
            SCNAction.moveBy(x: shakeAmount, y: 0, z: 0, duration: 0.04),
            SCNAction.moveBy(x: -shakeAmount * 2, y: 0, z: 0, duration: 0.04),
            SCNAction.moveBy(x: shakeAmount * 2, y: 0, z: shakeAmount, duration: 0.04),
            SCNAction.moveBy(x: -shakeAmount, y: 0, z: -shakeAmount, duration: 0.04),
        ])
        cameraNode.runAction(seq)
    }

    // MARK: - Combat: Player Attacks Monster
    func playerAttack(monster: Monster) {
        guard let p = player, p.hasAction else { return }
        p.hasAction = false
        let d20 = rollD(20)
        let isCrit = d20 == 20
        let isFumble = d20 == 1
        let total = d20 + p.attackMod
        let hit = isCrit || (!isFumble && total >= monster.ac)

        addLog("\(p.cls.rawValue) attacks \(monster.type.rawValue): d20(\(d20)) + \(p.attackMod) = \(total) vs AC \(monster.ac) — \(hit ? "HIT!" : "MISS!")")
        showDiceRoll(roll: d20, mod: p.attackMod, total: total, targetAC: monster.ac, hit: hit, isCrit: isCrit)

        if hit {
            let dmg = rollDice(count: p.damageDice.count, sides: p.damageDice.sides)
            var totalDmg = dmg.total + p.damageDice.bonus
            // Rogue sneak attack: if enemy hasn't acted this round
            if p.cls == .rogue && !monster.hasActed {
                let sneak = rollDice(count: 2, sides: 6)
                totalDmg += sneak.total
                addLog("  Sneak Attack! +\(sneak.total) damage")
            }
            // Warlock hex bonus
            if p.cls == .warlock && p.hexActive {
                let hexDmg = rollD(6)
                totalDmg += hexDmg
                addLog("  Hex! +\(hexDmg) damage")
            }
            // Crit = double dice
            if isCrit {
                let critExtra = rollDice(count: p.damageDice.count, sides: p.damageDice.sides)
                totalDmg += critExtra.total
                screenShake()
                addLog("  CRITICAL HIT! Extra \(critExtra.total) damage!")
            }
            if totalDmg < 1 { totalDmg = 1 }
            monster.hp -= totalDmg
            addLog("  \(p.cls.rawValue) deals \(totalDmg) damage to \(monster.type.rawValue)")
            showDamage(amount: totalDmg, desc: "")
            if let mNode = monster.node {
                showFloatingDamage(totalDmg, at: mNode.position)
                // Flash red
                mNode.enumerateChildNodes { (child, _) in
                    if let geo = child.geometry {
                        let origMats = geo.materials.map { $0.copy() as! SCNMaterial }
                        for mat in geo.materials { mat.emission.contents = NSColor.red }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            geo.materials = origMats
                        }
                    }
                }
            }
            if monster.hp <= 0 {
                killMonster(monster)
            }
        }
        clearHighlights()
        updateHUD()
    }

    func killMonster(_ monster: Monster) {
        guard let p = player else { return }
        addLog("\(monster.type.rawValue) is defeated!")
        p.xp += monster.xpValue
        p.kills += 1
        monster.node?.removeFromParentNode()
        monsters.removeAll { $0 === monster }
        // Check level up
        if p.canLevelUp() {
            p.levelUp()
            addLog("LEVEL UP! \(p.cls.rawValue) is now level \(p.level)!")
            showLevelUp()
        }
    }

    func showLevelUp() {
        levelUpLabel.alpha = 1.0
        let seq = SKAction.sequence([
            SKAction.wait(forDuration: 2.0),
            SKAction.fadeOut(withDuration: 0.5)
        ])
        levelUpLabel.run(seq)
    }

    // MARK: - Combat: Monster Attacks Player
    func monsterAttack(monster: Monster) {
        guard let p = player else { return }
        let d20 = rollD(20)
        let isCrit = d20 == 20
        let isFumble = d20 == 1
        let total = d20 + monster.attackBonus
        let hit = isCrit || (!isFumble && total >= p.ac)

        addLog("\(monster.type.rawValue) attacks \(p.cls.rawValue): d20(\(d20)) + \(monster.attackBonus) = \(total) vs AC \(p.ac) — \(hit ? "HIT!" : "MISS!")")

        if hit {
            let dmg = rollDice(count: monster.damageCount, sides: monster.damageDice)
            var totalDmg = dmg.total + monster.damageBonus
            if isCrit {
                let critExtra = rollDice(count: monster.damageCount, sides: monster.damageDice)
                totalDmg += critExtra.total
                screenShake()
                addLog("  CRITICAL HIT!")
            }
            if totalDmg < 1 { totalDmg = 1 }
            p.hp -= totalDmg
            addLog("  \(monster.type.rawValue) deals \(totalDmg) damage")
            if let pNode = p.node {
                showFloatingDamage(totalDmg, at: pNode.position)
            }
            if p.hp <= 0 {
                playerDeath()
            }
        }
        updateHUD()
    }

    // MARK: - Dragon Breath Weapon
    func dragonBreath(monster: Monster) {
        guard let p = player else { return }
        addLog("\(monster.type.rawValue) uses Breath Weapon!")
        let dmgRoll = rollDice(count: 4, sides: 6)
        let dexSave = rollD(20) + abilityMod(p.scores.dex)
        let dc = 14
        var totalDmg = dmgRoll.total
        if dexSave >= dc {
            totalDmg /= 2
            addLog("  DEX save(\(dexSave)) >= DC \(dc) — Half damage!")
        } else {
            addLog("  DEX save(\(dexSave)) < DC \(dc) — Full damage!")
        }
        p.hp -= totalDmg
        addLog("  Breath weapon deals \(totalDmg) fire damage!")
        if let pNode = p.node {
            showFloatingDamage(totalDmg, at: pNode.position)
        }
        if p.hp <= 0 { playerDeath() }
        monster.breathRecharge = 3
        updateHUD()
    }

    func playerDeath() {
        gameState = .dead
        guard let p = player else { return }
        addLog("The \(p.cls.rawValue) has fallen on floor \(currentFloor)...")
        deathLabel.text = "YOU DIED — Floor \(currentFloor), Level \(p.level), \(p.kills) kills"
        deathLabel.alpha = 1.0
        actionLabel.text = "Press ESC to restart"
        turnLabel.text = ""
    }

    // MARK: - Abilities
    func useAbility1() {
        guard let p = player, gameState == .playerTurn, p.hasAction, p.ability1Uses > 0 else { return }
        switch p.cls {
        case .fighter: // Second Wind: heal 1d10+level
            let heal = rollD(10) + p.level
            p.hp = min(p.maxHP, p.hp + heal)
            p.ability1Uses -= 1; p.hasAction = false
            addLog("Second Wind! Heal \(heal) HP.")
        case .rogue: // Cunning Action: double movement
            p.movementLeft = p.movementTiles * 2
            p.ability1Uses -= 1
            addLog("Cunning Action! Double movement this turn.")
            showMovementHighlights()
        case .cleric: // Healing Word: heal 1d8+WIS
            let heal = rollD(8) + abilityMod(p.scores.wis)
            p.hp = min(p.maxHP, p.hp + max(1, heal))
            p.ability1Uses -= 1; p.hasAction = false
            addLog("Healing Word! Heal \(max(1, heal)) HP.")
        case .wizard: // Magic Missile: 3d4+3 auto-hit
            if let target = nearestMonster(range: 6) {
                let dmg = rollDice(count: 3, sides: 4)
                let total = dmg.total + 3
                target.hp -= total
                p.ability1Uses -= 1; p.hasAction = false
                addLog("Magic Missile hits \(target.type.rawValue) for \(total) damage!")
                if let mn = target.node { showFloatingDamage(total, at: mn.position) }
                if target.hp <= 0 { killMonster(target) }
            } else {
                addLog("No target in range for Magic Missile!")
                return
            }
        case .warlock: // Eldritch Blast: 1d10+CHA ranged auto-hit
            if let target = nearestMonster(range: 6) {
                var total = rollD(10) + abilityMod(p.scores.cha)
                if p.hexActive { total += rollD(6); addLog("Hex bonus 1d6!") }
                if total < 1 { total = 1 }
                target.hp -= total
                p.hasAction = false
                addLog("Eldritch Blast hits \(target.type.rawValue) for \(total) damage!")
                if let mn = target.node { showFloatingDamage(total, at: mn.position) }
                if target.hp <= 0 { killMonster(target) }
            } else {
                addLog("No target in range for Eldritch Blast!")
                return
            }
        }
        clearHighlights()
        updateHUD()
    }

    func useAbility2() {
        guard let p = player, gameState == .playerTurn, p.hasAction, p.ability2Uses > 0 else { return }
        switch p.cls {
        case .fighter: // Action Surge: extra action
            p.hasAction = true
            p.ability2Uses -= 1
            addLog("Action Surge! Gain an extra action!")
            showMovementHighlights()
        case .rogue: // Evasion: passive, halve trap damage — just show message
            addLog("Evasion is passive — halves trap damage.")
            return
        case .cleric: // Sacred Flame: d8 ranged, DEX save
            if let target = nearestMonster(range: 6) {
                let dc = 8 + abilityMod(p.scores.wis) + p.profBonus
                let save = rollD(20) + 1 // monsters have ~+1 DEX save
                if save >= dc {
                    addLog("Sacred Flame: \(target.type.rawValue) DEX save(\(save)) >= DC \(dc) — dodged!")
                } else {
                    let dmg = rollD(8)
                    target.hp -= dmg
                    addLog("Sacred Flame hits \(target.type.rawValue) for \(dmg) radiant damage!")
                    if let mn = target.node { showFloatingDamage(dmg, at: mn.position) }
                    if target.hp <= 0 { killMonster(target) }
                }
                p.ability2Uses -= 1; p.hasAction = false
            } else {
                addLog("No target in range for Sacred Flame!")
                return
            }
        case .wizard: // Fireball: 8d6 AOE
            if let target = nearestMonster(range: 6) {
                let dmg = rollDice(count: 8, sides: 6)
                addLog("FIREBALL! \(dmg.total) fire damage!")
                // Hit all monsters within 2 tiles of target
                let bx = target.gridX; let by = target.gridY
                for m in monsters {
                    let dist = abs(m.gridX - bx) + abs(m.gridY - by)
                    if dist <= 2 {
                        let dexSave = rollD(20) + 1
                        let dc = 8 + abilityMod(p.scores.intel) + p.profBonus
                        var d = dmg.total
                        if dexSave >= dc { d /= 2 }
                        m.hp -= d
                        addLog("  \(m.type.rawValue) takes \(d) fire damage!")
                        if let mn = m.node { showFloatingDamage(d, at: mn.position) }
                    }
                }
                // Remove dead
                let dead = monsters.filter { $0.hp <= 0 }
                for d in dead { killMonster(d) }
                p.ability2Uses -= 1; p.hasAction = false
            } else {
                addLog("No target in range for Fireball!")
                return
            }
        case .warlock: // Hex: bonus d6 on all attacks this floor
            if !p.hexActive {
                p.hexActive = true
                p.ability2Uses -= 1; p.hasAction = false
                addLog("HEX activated! +1d6 damage on all attacks!")
            } else {
                addLog("Hex is already active!")
                return
            }
        }
        clearHighlights()
        updateHUD()
    }

    func nearestMonster(range: Int) -> Monster? {
        guard let p = player else { return nil }
        var best: Monster? = nil; var bestDist = Int.max
        for m in monsters {
            let dist = abs(m.gridX - p.gridX) + abs(m.gridY - p.gridY)
            if dist <= range && dist < bestDist {
                bestDist = dist; best = m
            }
        }
        return best
    }

    // MARK: - Player Movement
    func movePlayer(toX: Int, toY: Int) {
        guard let p = player, gameState == .playerTurn else { return }
        let dist = abs(toX - p.gridX) + abs(toY - p.gridY)
        if dist > p.movementLeft { return }
        if !dungeon.isWalkable(toX, toY) { return }
        if monsters.contains(where: { $0.gridX == toX && $0.gridY == toY && $0.hp > 0 }) { return }

        p.movementLeft -= dist
        p.gridX = toX; p.gridY = toY
        let targetPos = SCNVector3(CGFloat(toX) * tileSize, 0 as CGFloat, CGFloat(toY) * tileSize)
        p.node?.runAction(SCNAction.move(to: targetPos, duration: 0.2))

        dungeon.revealAround(toX, toY)

        // Check tile events
        let tile = dungeon.tiles[toY][toX]
        if tile == .trap {
            let dexSave = rollD(20) + abilityMod(p.scores.dex)
            let dc = 12
            var trapDmg = rollDice(count: 2, sides: 6).total
            if p.cls == .rogue { trapDmg /= 2 } // Evasion
            if dexSave >= dc {
                trapDmg /= 2
                addLog("Trap! DEX save(\(dexSave)) >= DC \(dc) — Half damage: \(trapDmg)")
            } else {
                addLog("Trap! DEX save(\(dexSave)) < DC \(dc) — Full damage: \(trapDmg)")
            }
            p.hp -= trapDmg
            if let pn = p.node { showFloatingDamage(trapDmg, at: pn.position) }
            dungeon.tiles[toY][toX] = .floor // Trap consumed
            if p.hp <= 0 { playerDeath(); return }
        }
        if tile == .chest {
            if Bool.random() {
                let heal = rollDice(count: 2, sides: 4).total + 2
                p.hp = min(p.maxHP, p.hp + heal)
                addLog("Chest: Found a healing potion! Heal \(heal) HP.")
            } else {
                let g = rollDice(count: 2, sides: 6).total * 5
                p.gold += g
                addLog("Chest: Found \(g) gold!")
            }
            dungeon.tiles[toY][toX] = .floor
            // Remove chest model
            let chestRemoveX = CGFloat(toX) * self.tileSize
            let chestRemoveZ = CGFloat(toY) * self.tileSize
            var nodesToRemove: [SCNNode] = []
            dungeonNode.enumerateChildNodes { (node, _) in
                if let box = node.geometry as? SCNBox,
                   box.width < 1.0 && box.height < 0.7,
                   abs(node.position.x - chestRemoveX) < 0.1 &&
                   abs(node.position.z - chestRemoveZ) < 0.1 {
                    nodesToRemove.append(node)
                }
            }
            for n in nodesToRemove { n.removeFromParentNode() }
        }
        if tile == .stairs {
            addLog("Descending to floor \(currentFloor + 1)...")
            gameState = .stairs
            currentFloor += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.startFloor()
            }
            return
        }

        showMovementHighlights()
        updateHUD()
    }

    // MARK: - End Player Turn
    func endPlayerTurn() {
        guard gameState == .playerTurn else { return }
        clearHighlights()
        gameState = .enemyTurn
        updateHUD()
        // Mark all enemies as not-acted for sneak attack tracking
        for m in monsters { m.hasActed = false }
        enemyActionIndex = 0
        processNextEnemy()
    }

    // MARK: - Enemy Turn
    func processNextEnemy() {
        if enemyActionIndex >= monsters.count || gameState == .dead {
            // All enemies done, back to player
            if gameState != .dead {
                gameState = .playerTurn
                player?.startTurn()
                showMovementHighlights()
                updateHUD()
            }
            return
        }
        let monster = monsters[enemyActionIndex]
        monster.hasActed = true
        enemyActionIndex += 1
        guard let p = player else { return }

        let dist = abs(monster.gridX - p.gridX) + abs(monster.gridY - p.gridY)

        // Dragon breath weapon
        if monster.type == .youngDragon && dist <= 3 && monster.breathRecharge <= 0 {
            dragonBreath(monster: monster)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                self?.processNextEnemy()
            }
            return
        }
        if monster.breathRecharge > 0 { monster.breathRecharge -= 1 }

        if dist <= 1 {
            // Adjacent — attack
            monsterAttack(monster: monster)
        } else {
            // Move toward player
            enemyMove(monster: monster)
            // Check if now adjacent
            let newDist = abs(monster.gridX - p.gridX) + abs(monster.gridY - p.gridY)
            if newDist <= 1 {
                monsterAttack(monster: monster)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.processNextEnemy()
        }
    }

    func enemyMove(monster: Monster) {
        guard let p = player else { return }
        var bestX = monster.gridX; var bestY = monster.gridY
        var bestDist = abs(monster.gridX - p.gridX) + abs(monster.gridY - p.gridY)

        for step in 0..<monster.speedTiles {
            let _ = step // suppress warning
            var moved = false
            for (dx, dy) in [(0, -1), (0, 1), (-1, 0), (1, 0), (-1, -1), (1, -1), (-1, 1), (1, 1)] {
                let nx = bestX + dx; let ny = bestY + dy
                if !dungeon.isWalkable(nx, ny) { continue }
                if nx == p.gridX && ny == p.gridY { continue }
                if monsters.contains(where: { $0 !== monster && $0.gridX == nx && $0.gridY == ny }) { continue }
                let d = abs(nx - p.gridX) + abs(ny - p.gridY)
                if d < bestDist {
                    bestDist = d; bestX = nx; bestY = ny; moved = true
                }
            }
            if !moved { break }
            monster.gridX = bestX; monster.gridY = bestY
        }
        let targetPos = SCNVector3(CGFloat(bestX) * tileSize, 0 as CGFloat, CGFloat(bestY) * tileSize)
        monster.node?.runAction(SCNAction.move(to: targetPos, duration: 0.2))
    }

    // MARK: - Click Handling
    func handleClick(at point: CGPoint, in view: SCNView) {
        if gameState == .classSelect {
            handleClassSelectClick(at: point)
            return
        }
        guard gameState == .playerTurn, let p = player else { return }

        let hitResults = view.hitTest(point, options: [
            SCNHitTestOption.searchMode: SCNHitTestSearchMode.closest.rawValue
        ])

        for hit in hitResults {
            let worldPos = hit.worldCoordinates
            let gx = Int(round(worldPos.x / tileSize))
            let gy = Int(round(worldPos.z / tileSize))

            // Check if clicking on a monster
            if let targetMonster = monsters.first(where: { $0.gridX == gx && $0.gridY == gy && $0.hp > 0 }) {
                let dist = abs(gx - p.gridX) + abs(gy - p.gridY)
                let range: Int
                switch p.cls {
                case .wizard: range = 6
                case .warlock: range = 6
                case .cleric: range = 1
                default: range = 1
                }
                if dist <= range && p.hasAction {
                    playerAttack(monster: targetMonster)
                    return
                } else if dist <= 1 && p.hasAction {
                    playerAttack(monster: targetMonster)
                    return
                }
            }

            // Move to tile
            if dungeon.isWalkable(gx, gy) {
                let dist = abs(gx - p.gridX) + abs(gy - p.gridY)
                if dist <= p.movementLeft && dist > 0 {
                    movePlayer(toX: gx, toY: gy)
                    return
                }
            }
            break
        }
    }

    func handleClassSelectClick(at point: CGPoint) {
        // Convert to HUD coordinates
        let hudPoint = CGPoint(x: point.x, y: point.y)
        for (i, btn) in classButtons.enumerated() {
            if btn.frame.contains(hudPoint) {
                let cls: [CharacterClass] = [.fighter, .rogue, .cleric, .wizard, .warlock]
                selectClass(cls[i])
                return
            }
        }
    }

    // MARK: - Key Handling
    func handleKeyDown(keyCode: UInt16) {
        if gameState == .classSelect {
            switch keyCode {
            case 18: selectClass(.fighter) // 1
            case 19: selectClass(.rogue)   // 2
            case 20: selectClass(.cleric)  // 3
            case 21: selectClass(.wizard)  // 4
            case 23: selectClass(.warlock) // 5
            default: break
            }
            return
        }
        if gameState == .dead {
            if keyCode == 53 { // ESC
                deathLabel.alpha = 0
                showClassSelect()
            }
            return
        }
        if gameState == .playerTurn {
            switch keyCode {
            case 18: useAbility1() // 1
            case 19: useAbility2() // 2
            case 49: endPlayerTurn() // Space
            case 53: // ESC
                deathLabel.alpha = 0
                showClassSelect()
            default: break
            }
        }
        if keyCode == 53 && gameState != .classSelect { // ESC from any state
            deathLabel.alpha = 0
            levelUpLabel.alpha = 0
            showClassSelect()
        }
    }

    // MARK: - Renderer Delegate
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.gameState != .classSelect && self.gameState != .dead {
                self.updateCamera()
            }
        }
    }
}

// MARK: - Custom SCNView for input handling
class GameSCNView: SCNView {
    var gameController: GameController?

    override var acceptsFirstResponder: Bool { return true }

    override func mouseDown(with event: NSEvent) {
        let loc = self.convert(event.locationInWindow, from: nil)
        // Also check HUD click
        if let gc = gameController {
            if gc.gameState == .classSelect {
                // HUD coordinates: SpriteKit y is flipped from AppKit
                let hudPt = CGPoint(x: loc.x, y: loc.y) // SCNView overlay uses same coords
                gc.handleClassSelectClick(at: hudPt)
                return
            }
            gc.handleClick(at: loc, in: self)
        }
    }

    override func keyDown(with event: NSEvent) {
        gameController?.handleKeyDown(keyCode: event.keyCode)
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var gameController: GameController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let rect = NSRect(x: 100, y: 100, width: 1280, height: 720)
        window = NSWindow(contentRect: rect,
                          styleMask: [.titled, .closable, .miniaturizable],
                          backing: .buffered, defer: false)
        window.title = "DUNGEONS & DICE"
        window.center()

        let scnView = GameSCNView(frame: NSRect(x: 0, y: 0, width: 1280, height: 720))
        scnView.antialiasingMode = .multisampling4X
        window.contentView = scnView

        gameController = GameController()
        scnView.gameController = gameController
        gameController.setup(view: scnView)

        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(scnView)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

// MARK: - Main Entry Point
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.activate(ignoringOtherApps: true)
app.run()