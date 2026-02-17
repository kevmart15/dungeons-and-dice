# Dungeons and Dice

A classic dungeon-crawling RPG built with Swift, featuring turn-based combat, character progression, and procedurally generated adventures.

## 🎮 Overview

Dungeons and Dice is a text-based dungeon crawler inspired by classic tabletop RPGs. Explore multiple villages, accept quests from the guild, delve into dangerous dungeons, and battle fearsome monsters using D&D-style dice mechanics.

## ✨ Features

### Character System
- **5 Playable Classes**: Fighter, Rogue, Cleric, Wizard, and Warlock
- **Ability Scores**: Classic D&D stats (STR, DEX, CON, INT, WIS, CHA)
- **Character Progression**: Level up and gain new abilities
- **Guild Ranks**: Progress from Copper to Platinum rank

### Combat & Gameplay
- **Turn-Based Combat**: Strategic D&D-style dice rolling mechanics
- **Status Effects**: Poison, stun, slow, bless, and shield effects
- **Diverse Enemies**: 12 monster types including Giant Rats, Goblins, Skeletons, Orcs, Trolls, and Dragons
- **Challenge Rating System**: Balanced encounters based on character level

### World & Exploration
- **5 Major Locations**: Oakvale, Silverwood, Ironhold, Marshfen, and The Wilds
- **Multiple Dungeons**: Goblin Caves, Undead Crypt, Dragon's Lair, and more
- **Interactive Buildings**: Inns, Guilds, Shops, Blacksmiths, and more
- **NPC System**: Dialogue and patrol system for living world feel

### Quest System
- **Quest Types**: Kill, Retrieve, Explore, and Escort missions
- **Guild Quests**: Accept contracts from the Adventurer's Guild
- **Rewards**: Earn experience points and gold for completing quests

### Economy & Items
- **Multiple Shops**: General Store, Herbalist, Blacksmith, Master Forge
- **Item Types**: Potions, Antidotes, Rations, Weapon Upgrades, Armor Upgrades
- **Consumables**: Healing Potions, Speed Potions, Strength Potions

## 🎲 Game Mechanics

### Dice Rolling
The game uses classic D&D dice mechanics:
- Ability score generation using 4d6 drop lowest
- Combat uses various dice (d4, d6, d8, d10, d12, d20)
- Attack rolls, damage rolls, and ability checks

### Character Creation
- Choose from 5 distinct classes
- Ability scores are automatically generated and optimized for your class
- Each class has unique stat priorities and playstyles

### Monster Encounters
- **CR 0.25**: Giant Rat, Goblin
- **CR 0.5**: Skeleton Warrior, Skeleton Archer
- **CR 1**: Orc Berserker, Giant Spider
- **CR 2**: Dark Mage, Troll, Mimic
- **CR 3**: Wraith, Ogre
- **CR 5**: Young Dragon

## 🛠️ Tech Stack

- **Language**: Swift
- **Graphics**: SceneKit (3D), SpriteKit (2D)
- **UI Framework**: AppKit
- **Platform**: macOS

## 🚀 Getting Started

### Prerequisites
- macOS 10.15 or later
- Xcode 13.0 or later

### Installation

1. Clone the repository:
```bash
git clone https://github.com/kevmart15/dungeons-and-dice.git
cd dungeons-and-dice
```

2. Compile the game:
```bash
swiftc main.swift -o dungeons-and-dice
```

3. Run the game:
```bash
./dungeons-and-dice
```

Alternatively, you can run the pre-built `.app` bundle:
```bash
open DungeonsAndDice.app
```

## 🎯 How to Play

1. **Create Your Character**: Choose a class and generate ability scores
2. **Visit the Village**: Explore towns, talk to NPCs, and visit shops
3. **Accept Quests**: Visit the Adventurer's Guild to take on contracts
4. **Enter Dungeons**: Delve into dangerous locations to fight monsters
5. **Level Up**: Gain XP from combat and quests to increase your power
6. **Manage Resources**: Buy potions, upgrade equipment, and rest at inns

## 🗺️ Locations

- **Oakvale**: Starting village with basic amenities
- **Silverwood**: Forest settlement with archery trainers
- **Ironhold**: Mining town with master blacksmiths
- **Marshfen**: Swamp village with herbalists
- **The Wilds**: Dangerous frontier region

## 📜 License

This project is open source and available under the MIT License.

## 👤 Author

**kevmart15**
- GitHub: [@kevmart15](https://github.com/kevmart15)

## 🤝 Contributing

Contributions, issues, and feature requests are welcome!

---

*Roll for initiative!* 🎲
