/* SPDX-License-Identifier: BSD-3-Clause
 * Copyright 2018 Jacob Keller. All rights reserved.
 *
 * Some structure definitions and names taken from https://www.deltaconnected.com/arcdps/evtc
 *
 * nlohmann/json.hpp is licensed under the MIT license.
 */
#include <iostream>
#include <fstream>
#include <string>
#include <sstream>
#include <cstring>
#include <cerrno>
#include <cctype>
#include <iomanip>
#include <map>
#include <type_traits>
#include "json.hpp"

using namespace std;
using json = nlohmann::json;

static const string version = "v2.4.0";

/*
 * The following enumeration definitions were taken from the
 * evtc README.txt file available at:
 *
 * https://www.deltaconnected.com/arcdps/evtc/README.txt
 *
 * They were last updated on March 30th, 2019.
 */

/* iff */
enum iff {
    IFF_FRIEND,
    IFF_FOE,
    IFF_UNKNOWN // or uncertain
};

/* combat result (physical) */
enum cbtresult {
    CBTR_NORMAL,      // good physical hit
    CBTR_CRIT,        // physical hit was crit
    CBTR_GLANCE,      // physical hit was glance
    CBTR_BLOCK,       // physical hit was blocked eg. mesmer shield 4
    CBTR_EVADE,       // physical hit was evaded, eg. dodge or mesmer sword 2
    CBTR_INTERRUPT,   // physical hit interrupted something
    CBTR_ABSORB,      // physical hit was "invlun" or absorbed eg. guardian elite
    CBTR_BLIND,       // physical hit missed
    CBTR_KILLINGBLOW, // hit was killing hit
    CBTR_DOWNED,      // hit was downing hit
};

/* combat activation */
enum cbtactivation {
    ACTV_NONE,          // not used - not this kind of event
    ACTV_NORMAL,        // started skill activation without quickness
    ACTV_QUICKNESS,     // started skill activation with quickness
    ACTV_CANCEL_FIRE,   // stopped skill activation with reaching tooltip time
    ACTV_CANCEL_CANCEL, // stopped skill activation without reaching tooltip time
    ACTV_RESET          // animation completed fully
};

/* combat state change */
enum cbtstatechange {
    CBTS_NONE,            // not used - not this kind of event
    CBTS_ENTERCOMBAT,     // src_agent entered combat, dst_agent is subgroup
    CBTS_EXITCOMBAT,      // src_agent left combat
    CBTS_CHANGEUP,        // src_agent is now alive
    CBTS_CHANGEDEAD,      // src_agent is now dead
    CBTS_CHANGEDOWN,      // src_agent is now downed
    CBTS_SPAWN,           // src_agent is now in game tracking range (not in realtime api)
    CBTS_DESPAWN,         // src_agent is no longer being tracked (not in realtime api)
    CBTS_HEALTHUPDATE,    // src_agent has reached a health marker. dst_agent = percent * 10000 (eg. 99.5% will be 9950) (not in realtime api)
    CBTS_LOGSTART,        // log start. value = server unix timestamp **uint32**. buff_dmg = local unix timestamp. src_agent = 0x637261 (arcdps id)
    CBTS_LOGEND,          // log end. value = server unix timestamp **uint32**. buff_dmg = local unix timestamp. src_agent = 0x637261 (arcdps id)
    CBTS_WEAPSWAP,        // src_agent swapped weapon set. dst_agent = current set id (0/1 water, 4/5 land)
    CBTS_MAXHEALTHUPDATE, // src_agent has had it's maximum health changed. dst_agent = new max health (not in realtime api)
    CBTS_POINTOFVIEW,     // src_agent is agent of "recording" player
    CBTS_LANGUAGE,        // src_agent is text language
    CBTS_GWBUILD,         // src_agent is game build
    CBTS_SHARDID,         // src_agent is sever shard id
    CBTS_REWARD,          // src_agent is self, dst_agent is reward id, value is reward type. these are the wiggly boxes that you get
    CBTS_BUFFINITIAL,     // combat event that will appear once per buff per agent on logging start (statechange==18, buff==18, normal cbtevent otherwise)
    CBTS_POSITION,        // src_agent changed, cast float* p = (float*)&dst_agent, access as x/y/z (float[3]) (not in realtime api)
    CBTS_VELOCITY,        // src_agent changed, cast float* v = (float*)&dst_agent, access as x/y/z (float[3]) (not in realtime api)
    CBTS_FACING,          // src_agent changed, cast float* f = (float*)&dst_agent, access as x/y (float[2]) (not in realtime api)
    CBTS_TEAMCHANGE,      // src_agent change, dst_agent new team id
    CBTS_ATTACKTARGET,    // src_agent is an attacktarget, dst_agent is the parent agent (gadget type), value is the current targetable state (not in realtime api)
    CBTS_TARGETABLE,      // dst_agent is new target-able state (0 = no, 1 = yes. default yes) (not in realtime api)
    CBTS_MAPID,           // src_agent is map id
    CBTS_REPLINFO,        // internal use, won't see anywhere
    CBTS_STACKACTIVE,     // src_agent is agent with buff, dst_agent is the stackid marked active
    CBTS_STACKRESET,      // src_agent is agent with buff, value is the duration to reset to (also marks inactive), pad61- is the stackid
    CBTS_GUILD            // src_agent is agent, dst_agent through buff_dmg is 16 byte guid (client form, needs minor rearrange for api form)
};

/* combat buff remove type */
enum cbtbuffremove {
    CBTB_NONE,   // not used - not this kind of event
    CBTB_ALL,    // last/all stacks removed (sent by server)
    CBTB_SINGLE, // single stack removed (sent by server). will happen for each stack on cleanse
    CBTB_MANUAL, // single stack removed (auto by arc on ooc or all stack, ignore for strip/cleanse calc, use for in/out volume)
};

/* custom skill ids */
enum cbtcustomskill {
    CSK_RESURRECT = 1066, // not custom but important and unnamed
    CSK_BANDAGE = 1175,   // personal healing only
    CSK_DODGE = 65001     // will occur in is_activation==normal event
};

/* language */
enum gwlanguage {
    GWL_ENG = 0,
    GWL_FRE = 2,
    GWL_GEM = 3,
    GWL_SPA = 4,
};

/* define agent. stats range from 0-10 */
struct evtc_agent {
    uint64_t addr;
    uint32_t prof;
    uint32_t is_elite;
    uint16_t toughness;
    uint16_t concentration;
    uint16_t healing;
    uint16_t hitbox_width;
    uint16_t condition;
    uint16_t hitbox_height;
    char name[64];
};

/* define skill */
struct evtc_skill {
    int32_t id;
    char name[64];
};

/* combat event (old, when header[12] == 0) */
struct evtc_cbtevent_v0 {
    uint64_t time;                 /* timegettime() at time of event */
    uint64_t src_agent;            /* unique identifier */
    uint64_t dst_agent;            /* unique identifier */
    int32_t value;                 /* event-specific */
    int32_t buff_dmg;              /* estimated buff damage. zero on application event */
    uint16_t overstack_value;      /* estimated overwritten stack duration for buff application */
    uint16_t skillid;              /* skill id */
    uint16_t src_instid;           /* agent map instance id */
    uint16_t dst_instid;           /* agent map instance id */
    uint16_t src_master_instid;    /* master source agent map instance id if source is a minion/pet */
    uint8_t iss_offset;            /* internal tracking. garbage */
    uint8_t iss_offset_target;     /* internal tracking. garbage */
    uint8_t iss_bd_offset;         /* internal tracking. garbage */
    uint8_t iss_bd_offset_target;  /* internal tracking. garbage */
    uint8_t iss_alt_offset;        /* internal tracking. garbage */
    uint8_t iss_alt_offset_target; /* internal tracking. garbage */
    uint8_t skar;                  /* internal tracking. garbage */
    uint8_t skar_alt;              /* internal tracking. garbage */
    uint8_t skar_use_alt;          /* internal tracking. garbage */
    uint8_t iff;                   /* from iff enum */
    uint8_t buff;                  /* buff application, removal, or damage event */
    uint8_t result;                /* from cbtresult enum */
    uint8_t is_activation;         /* from cbtactivation enum */
    uint8_t is_buffremove;         /* buff removed. src=relevant, dst=caused it (for strips/cleanses). from cbtr enum */
    uint8_t is_ninety;             /* source agent health was over 90% */
    uint8_t is_fifty;              /* target agent health was under 50% */
    uint8_t is_moving;             /* source agent was moving */
    uint8_t is_statechange;        /* from cbtstatechange enum */
    uint8_t is_flanking;           /* target agent was not facing source */
    uint8_t is_shields;            /* all or part damage was vs barrier/shield */
    uint8_t is_offcycle;           /* zero if buff dmg happened during tick, non-zero otherwise */
    uint8_t pad64;                 /* internal tracking. garbage */
};

/* Guild UIDs are 16byte values which are stored over the dst_agent, value,
 * and buff_dmg members of the evtc_cbtevent values.
 */
struct evtc_guid {
    struct {
        uint32_t p1; /* Little Endian */
        uint16_t p2; /* Little Endian */
        uint16_t p3; /* Little Endian */
        uint16_t p4; /* Big Endian */
        uint16_t p5; /* Big Endian*/
        uint32_t p6; /* Big Endian */
    } data;
    uint8_t valid;
};

/* combat event logging (revision 1, when header[12] == 1) */
struct evtc_cbtevent_v1 {
    uint64_t time;
    uint64_t src_agent;
    uint64_t dst_agent;
    int32_t value;
    int32_t buff_dmg;
    uint32_t overstack_value;
    uint32_t skillid;
    uint16_t src_instid;
    uint16_t dst_instid;
    uint16_t src_master_instid;
    uint16_t dst_master_instid;
    uint8_t iff;
    uint8_t buff;
    uint8_t result;
    uint8_t is_activation;
    uint8_t is_buffremove;
    uint8_t is_ninety;
    uint8_t is_fifty;
    uint8_t is_moving;
    uint8_t is_statechange;
    uint8_t is_flanking;
    uint8_t is_shields;
    uint8_t is_offcycle;
    uint8_t pad61;
    uint8_t pad62;
    uint8_t pad63;
    uint8_t pad64;
};

static const uint8_t cbtevent_revision_v0 = 0;
static const uint8_t cbtevent_revision_v1 = 1;

static const size_t cbtevent_sizes[] = {
    sizeof(evtc_cbtevent_v0),
    sizeof(evtc_cbtevent_v1),
};

static const uint8_t max_cbtevent_revision = 1;
static_assert(max_cbtevent_revision < extent<decltype(cbtevent_sizes)>::value,
              "Invalid maximum cbtevent revision");
static const uint32_t EVTC_CBTEVENT_SIZE(uint8_t revision);

/* The evtc_cbtevent structure is used to abstract away the layout differences
 * of the different versions of the cbtevent data in evtc_cbtevent_v0 and
 * evtc_cbtevent_v1 data structures. Because of this, we need to write accessor
 * functions in the class. However, much of this code is boiler plate. Almost
 * every field has the same name. A few fields have different sizes, but can be
 * easily type-casted up to the larger size.
 *
 * This macro is provided as a convenient way to define accessors for the most
 * common fields that do not need any special handling between versions.
 * Otherwise we would end up duplicating this boiler plate revision version
 * check many times.
 */
#define CBTEVENT_ACCESSOR(type, field)                                         \
  type field()                                                                 \
  {                                                                            \
    if (revision == cbtevent_revision_v0)                                      \
      return (type)(raw.v0.field);                                             \
    else if (revision == cbtevent_revision_v1)                                 \
      return (type)(raw.v1.field);                                             \
    else                                                                       \
      throw "Invalid cbtevent revision";                                       \
  }

/* Abstraction of the various evtc_cbtevent versions */
class evtc_cbtevent
{
private:
    union {
        evtc_cbtevent_v0 v0;
        evtc_cbtevent_v1 v1;
    } raw;
    uint8_t revision;
public:
    evtc_cbtevent(ifstream& file, uint8_t revision,
                  streampos cbt_event_start,
                  uint32_t cbtevent);

    CBTEVENT_ACCESSOR(uint8_t, is_statechange)
    CBTEVENT_ACCESSOR(uint64_t, src_agent)
    CBTEVENT_ACCESSOR(uint64_t, dst_agent)
    CBTEVENT_ACCESSOR(uint32_t, value)
    CBTEVENT_ACCESSOR(uint64_t, time)

    struct evtc_guid guid()
    {
        struct evtc_guid guid = {};

        if (revision == cbtevent_revision_v0) {
            /* v0 never supported CBTS_GUILD events... */
            memcpy(&guid.data, &raw.v0.dst_agent, sizeof(guid.data));
            guid.valid = true;
        } else if (revision == cbtevent_revision_v1) {
            memcpy(&guid.data, &raw.v1.dst_agent, sizeof(guid.data));
            guid.valid = true;
        } else {
            throw "Invalid cbtevent revision";
        }

#define BSWAP16(val) val = __builtin_bswap16(val)
#define BSWAP32(val) val = __builtin_bswap32(val)

        /* Some of the bytes in the GUID are stored in Big Endian format,
         * so we need to swap them back into the right order for use with
         * the GW2 API.
         *
         * Since we're assuming the host is "Little Endian" format, we only
         * need to swap the values which are "Big Endian".
         */
        BSWAP16(guid.data.p4);
        BSWAP16(guid.data.p5);
        BSWAP32(guid.data.p6);

        return guid;
    };
};

/**
 * evtc_cbtevent - Construct an EVTC combat event from the file
 * @file: the file to read
 * @revision: the combat event revision
 * @cbt_event_start: where in the file combat events start
 * @cbtevent: which combat event number to read
 *
 * Construct an evtc_cbtevent item by reading from the given file.
 */
evtc_cbtevent::evtc_cbtevent(ifstream& file,
                             uint8_t revision,
                             streampos cbt_event_start,
                             uint32_t cbtevent)
{
    streampos event_index = cbt_event_start;
    event_index += cbtevent * EVTC_CBTEVENT_SIZE(revision);
    file.seekg(event_index);
    file.read((char *)&this->raw, EVTC_CBTEVENT_SIZE(revision));
    this->revision = revision;
}

static const string valid_types[] = {
    "version",
    "json",
    "header",
    "revision",
    "players",
    "success",
    "start_time",
    "end_time",
    "local_start_time",
    "local_end_time",
    "boss_maxhealth",
    "is_cm",
    "duration",
    "location",
};

static const int valid_types_size = extent<decltype(valid_types)>::value;

/* Positions for various useful data in the evtc file format
 *
 * The first few are static, but later parts of the file are
 * dependent on how many agents, skills, and combat events
 * are recorded.
 */
static const streampos SEEKG_EVTC_HEADER = 0;
static const streampos EVTC_HEADER_SIZE = 16; /* 16 bytes */

static const streampos SEEKG_EVTC_AGENT_COUNT = SEEKG_EVTC_HEADER + EVTC_HEADER_SIZE;
static const streampos EVTC_AGENT_COUNT_SIZE = sizeof(uint32_t); /* 4 bytes */

static const streampos SEEKG_EVTC_FIRST_AGENT = SEEKG_EVTC_AGENT_COUNT + EVTC_AGENT_COUNT_SIZE;

static const streampos SEEKG_EVTC_SKILL_COUNT(uint32_t agent_count)
{
    return (SEEKG_EVTC_FIRST_AGENT + streampos(sizeof(evtc_agent) * agent_count));
}
static const streampos EVTC_SKILL_COUNT_SIZE = sizeof(uint32_t); /* 4 bytes */

static const streampos SEEKG_EVTC_FIRST_SKILL(uint32_t agent_count)
{
    return SEEKG_EVTC_SKILL_COUNT(agent_count) + EVTC_SKILL_COUNT_SIZE;
}

static const streampos SEEKG_EVTC_FIRST_CBTEVENT(uint32_t agent_count, uint32_t skill_count)
{
    return (SEEKG_EVTC_FIRST_SKILL(agent_count) + streampos(sizeof(evtc_skill) * skill_count));
}

static const uint32_t EVTC_CBTEVENT_SIZE(uint8_t revision)
{
    if (revision > max_cbtevent_revision)
        throw "Invalid EVTC cbtevent revision";

    return cbtevent_sizes[revision];
}

enum cm_type {
    CM_UNKNOWN,
    CM_HEALTH_BASED,
    CM_NO,
    CM_YES,
};

/*
 * @struct encounter_info
 * @brief Encounter data determined based on encounter ID
 *
 * Structure which represents encounter data based on the EVTC encounter ID.
 * This includes the human readable name and location (wing) that the encounter
 * belongs in.
 *
 * @note By convention, raid wings will have their location set as a number
 * based on the release order of the raid wing. Fractals and other encounters
 * will set their location based on the name of the area in game.
 */
struct encounter_info {
    const char *name;
    const char *location;
    enum cm_type cm;
    uint64_t health_threshold;
};

static const std::map<uint16_t, struct encounter_info> all_encounter_info = {
    /* Raid Wing 1 */
    {0x3C4E, {"Vale Guardian", "1", CM_NO, 0}},
    {0x3C45, {"Gorseval", "1", CM_NO, 0}},
    {0x3C0F, {"Sabetha", "1", CM_NO, 0}},
    /* Raid Wing 2 */
    {0x3EFB, {"Slothasor", "2", CM_NO, 0}},
    {0x3ED8, {"Bandit Trio", "2", CM_NO, 0}},
    {0x3F09, {"Bandit Trio", "2", CM_NO, 0}},
    {0x3EFD, {"Bandit Trio", "2", CM_NO, 0}},
    {0x3EF3, {"Matthias", "2", CM_NO, 0}},
    /* Raid Wing 3 */
    {0x3F6B, {"Keep Construct", "3", CM_NO, 0}},
    {0x3F77, {"Twisted Castle", "3", CM_NO, 0}},
    {0x3F76, {"Xera", "3", CM_NO, 0}},
    {0x3F9E, {"Xera", "3", CM_NO, 0}},
    /* Raid Wing 4 */
    {0x432A, {"Cairn", "4", CM_UNKNOWN, 0}},
    {0x4314, {"Mursaat Overseer", "4", CM_HEALTH_BASED, 25000000}},
    {0x4324, {"Samarog", "4", CM_HEALTH_BASED, 35000000}},
    {0x4302, {"Deimos", "4", CM_HEALTH_BASED, 40000000}},
    /* Raid Wing 5 */
    {0x4d37, {"Soulless Horror", "5", CM_UNKNOWN, 0}},
    {0x4d74, {"Rainbow Road", "5", CM_NO, 0}},
    {0x4ceb, {"Broken King", "5", CM_NO, 0}},
    {0x4c50, {"Soul Eater", "5", CM_NO, 0}},
    {0x4cc3, {"Eye of Judgement", "5", CM_NO, 0}},
    {0x4d84, {"Eye of Fate", "5", CM_NO, 0}},
    {0x4bfa, {"Dhuum", "5", CM_HEALTH_BASED, 35000000}},
    /* Raid Wing 6 */
    {0xabc6, {"Conured Amalgamate", "6", CM_UNKNOWN, 0}},
    {0x5271, {"Largos Twins", "6", CM_HEALTH_BASED, 18000000}},
    {0x5261, {"Largos Twins", "6", CM_HEALTH_BASED, 18000000}},
    {0x51c6, {"Qadim", "6", CM_HEALTH_BASED, 21000000}},
    /* Raid Wing 7 */
    {0x55f6, {"Cardinal Adina", "7", CM_UNKNOWN, 0}},
    {0x55cc, {"Cardinal Sabir", "7", CM_UNKNOWN, 0}},
    {0x55f0, {"Qadim the Peerless", "7", CM_UNKNOWN, 0}},
    /* Winter Strike Mission */
    {0x5355, {"Freezie", "Wintersday", CM_NO, 0}},
    /* Fractal 99 CM */
    {0x427d, {"MAMA (CM)", "99cm", CM_NO, 0}},
    {0x4284, {"Siax (CM)", "99cm", CM_NO, 0}},
    {0x4234, {"Ensolyss (CM)", "99cm", CM_NO, 0}},
    /* Fractal 100 CM */
    {0x44e0, {"Skorvald the Shattered (CM)", "100cm", CM_NO, 0}},
    {0x461d, {"Artsariiv (CM)", "100cm", CM_NO, 0}},
    {0x455f, {"Arkk (CM)", "100cm", CM_NO, 0}},
    /* Aquatic Ruins Fractal */
    {0x2C8A, {"Jellyfish Beast", "Aquatic Ruins", CM_NO, 0}},
    /* Captain Mai Trin Boss */
    {0x4263, {"Champion Inquest Technician", "Mai Trin Boss", CM_NO, 0}},
    {0x2fea, {"Mai Trin", "Mai Trin Boss", CM_NO, 0}},
    /* Chaos Isles Fractal */
    {0x40E9, {"Brazen Gladiator", "Chaos Isles", CM_NO, 0}},
    /* Cliffside Fractal */
    {0x2C20, {"Archdiviner", "Cliffside", CM_NO, 0}},
    /* Molten Boss */
    {0x325E, {"Molten Effigy", "Molten Boss", CM_NO, 0}},
    /* Nightmare */
    {0x4268, {"MAMA", "Nightmare", CM_NO, 0}},
    {0x4215, {"Siax the Unclean", "Nightmare", CM_NO, 0}},
    {0x429B, {"Ensolyss", "Nightmare", CM_NO, 0}},
    /* Shattered Observatory */
    {0x44E0, {"Skorvald the Shattered", "Shattered Observatory", CM_NO, 0}},
    /* Snowblind */
    {0x2C45, {"Svanir Shaman", "Snowblind", CM_NO, 0}},
    /* Solid Ocean */
    {0x2BF6, {"The Jade Maw", "Solid Ocean", CM_NO, 0}},
    /* Swampland */
    {0x2C00, {"Mossman", "Swampland", CM_NO, 0}},
    {0x2C01, {"Bloomhunger", "Swampland", CM_NO, 0}},
    /* Thaumanova Reactor */
    {0x3268, {"Subject 6", "Thaumanova", CM_NO, 0}},
    {0x326A, {"Thaumanova Anomaly", "Thaumanova", CM_NO, 0}},
    /* Underground Facility */
    {0x2BE9, {"Rabsovich", "Underground Facility", CM_NO, 0}},
    {0x2BE8, {"Rampaging Ice Elemental", "Underground Facility", CM_NO, 0}},
    {0x2BE7, {"Dredge Powersuit", "Underground Facility", CM_NO, 0}},
    /* Urban Battleground */
    {0x2C9D, {"Siegemaster Dulfy", "Urban Battleground", CM_NO, 0}},
    {0x2C90, {"Captain Ashym", "Urban Battleground", CM_NO, 0}},
    /* Volcanic */
    {0x2CDC, {"Grawl Shaman", "Volcanic", CM_NO, 0}},
    {0x2CDD, {"Imbued Shaman", "Volcanic", CM_NO, 0}},
    /* Uncategorized */
    {0x2C41, {"Uncategorized Champions", "Uncategorized", CM_NO, 0}},
    {0x2C44, {"Uncategorized Champions", "Uncategorized", CM_NO, 0}},
    {0x2C43, {"Uncategorized Champions", "Uncategorized", CM_NO, 0}},
    {0x2C3A, {"Old Tom", "Uncategorized", CM_NO, 0}},
    {0x2C3D, {"Raving Asura", "Uncategorized", CM_NO, 0}},
    {0x2C3C, {"Raving Asura", "Uncategorized", CM_NO, 0}},
    {0x2C3E, {"Raving Asura", "Uncategorized", CM_NO, 0}},
    {0x2C3F, {"Raving Asura", "Uncategorized", CM_NO, 0}},
    /* Training Golems */
    {0x3f46, {"Vital Kitty Golem (10m HP)", "Training Golem", CM_NO, 0}},
    {0x3f31, {"Average Kitty Golem (4m HP)", "Training Golem", CM_NO, 0}},
    {0x3f47, {"Standard Kitty Golem (1m HP)", "Training Golem", CM_NO, 0}},
    {0x3f29, {"Massive Kitty Golem (10m HP)", "Training Golem", CM_NO, 0}},
    {0x3f4a, {"Massive Kitty Golem (4m HP)", "Training Golem", CM_NO, 0}},
    {0x3f32, {"Massive Kitty Golem (1m HP)", "Training Golem", CM_NO, 0}},
    {0x3f2e, {"Tough Kitty Golem", "Training Golem", CM_NO, 0}},
    {0x3f30, {"Resistant Kitty Golem", "Training Golem", CM_NO, 0}},
    {0x4cdc, {"Large Kitty Golem (4m HP)", "Training Golem", CM_NO, 0}},
    {0x4cbd, {"Medium Kitty Golem (4m HP)", "Training Golem", CM_NO, 0}},
};

static const uint64_t arcdps_src_agent = 0x637261;

/* is_elite value indicating a non-player object */
static const uint32_t EVTC_AGENT_NON_PLAYER_AGENT = 0xffffffff;

/* upper bits of profession indicating whether this agent is a gadget */
static const uint32_t EVTC_AGENT_GADGET_AGENT = 0xffff0000;

/* lower bits of profession indicating species id of this agent */
static const uint32_t EVTC_AGENT_SPECIES_ID_MASK = 0x0000ffff;

struct player_details {
    string character;
    string account;
    string subgroup;

    /* EVTC agent identifier */
    uint64_t addr;

    /* 16-byte Guild UID */
    struct evtc_guid guid;
};

struct parsed_details {
    /* Metadata */
    uint32_t agent_count;
    uint32_t skill_count;
    uint32_t cbt_event_count;
    streampos cbt_event_start;

    /* Extracted data */
    char arc_header[13];
    uint8_t revision;
    uint16_t boss_id;
    struct encounter_info boss_info;
    uint64_t boss_src_agent;
    uint64_t boss_maxhealth;
    uint32_t server_start;
    uint32_t server_end;
    uint64_t precise_last_event;
    uint64_t precise_logend_time;
    uint64_t precise_reward_time;
    uint64_t precise_start;
    uint64_t precise_end;
    bool encounter_success;
    map<uint64_t, player_details> players;
};

/**
 * parse_header: extract details from the EVTC header line
 * @details: data structure to hold extracted data
 * @file: the ifstream to read from
 *
 * Parse the @file for an EVTC header, and validate that it is, then
 * extract the file version, encounter id, and boss name into the
 * @details structure. Otherwise, return a negative error code.
 */
static int
parse_header(parsed_details& details, ifstream& file)
{
    char raw_header[16];

    /* The evtc file has a 16 byte header. It consists of
     * 4 bytes containing "EVTC", followed by 8 bytes
     * with a YYYYMMDD representing the arcdps build,
     * followed by a NUL byte, followed by 2 bytes holding
     * the area encounter id, followed by another NUL
     */
    file.seekg(SEEKG_EVTC_HEADER);
    file.read(raw_header, 16);

    /* Make sure we have the 4 bytes of EVTC */
    if (strncmp(raw_header, "EVTC", 4)) {
        return -EINVAL;
    }

    /* Make sure the version is a number */
    for (int i = 4; i < 12; i++) {
        if (!isdigit(raw_header[i])) {
            return -EINVAL;
        }
    }

    /* Extract the main EVTC header string */
    memcpy(details.arc_header, raw_header, 12);
    details.arc_header[12] = '\0';

    /* Extract the cbtevent revision */
    details.revision = raw_header[12];

    /* Only v0 and v1 are currently supported */
    if (details.revision > 1) {
        return -EINVAL;
    }

    /* Make sure there is a NUL in the byte following the area id */
    if (raw_header[15] != '\0') {
        return -EINVAL;
    }

    /* extract the area id */
    memcpy(&details.boss_id, &raw_header[13], sizeof(uint16_t));
    auto iter = all_encounter_info.find(details.boss_id);

    if (iter != all_encounter_info.end()) {
        details.boss_info = iter->second;
    } else {
        std::stringstream ss;
        ss << "Unknown encounter " << details.boss_id;
        details.boss_info.name = std::move(ss.str().c_str());
        details.boss_info.cm = CM_UNKNOWN;
        details.boss_info.health_threshold = 0;
    }

    return 0;
}

/**
 * parse_agent_count: extract the agent count from the file
 * @details: structure to hold extracted data and metadata
 * @file: the file to scan from
 *
 * Seeks to the location of the EVTC file and reads the count
 * of the number of agent objects stored in the file. Assumes the
 * file has already been validated by parse_header.
 */
static void
parse_agent_count(parsed_details& details, ifstream& file)
{
    file.seekg(SEEKG_EVTC_AGENT_COUNT);
    file.read((char *)&details.agent_count, sizeof(uint32_t));
}

/**
 * get_agent_details: extract one agent details object from the file
 * @file: the file to read from
 * @agent: which agent from the array to read
 * @agent_details: structure to hold the agent data
 *
 * Seeks to the point where agent data for the @agent number is located
 * and reads it into the @agent_details structure.
 */
static void
get_agent_details(ifstream& file, uint32_t agent, evtc_agent& agent_details)
{
    uint32_t fdindex = SEEKG_EVTC_FIRST_AGENT;

    fdindex += agent * sizeof(evtc_agent);

    file.seekg(fdindex);
    file.read((char *)&agent_details, sizeof(evtc_agent));
}

/**
 * parse_player_agent: parse player data out of an agent data structure
 * @details: data structure to hold parsed EVTC data
 * @file: the EVTC file to scan
 * @agent: the agent number to read
 *
 * Extracts agent data for a given @agent number, and determines if it's a
 * player agent. If so, store the player data within @details.players
 */
static void
parse_player_agent(parsed_details& details, ifstream& file, unsigned int agent)
{
    evtc_agent agent_details = {};
    player_details player = {};
    char *name;

    /* Copy the agent details from the file */
    get_agent_details(file, agent, agent_details);

    if (agent_details.is_elite == EVTC_AGENT_NON_PLAYER_AGENT) {
        return;
    }

    player.addr = agent_details.addr;

    /* The EVTC format stores the name as a sequence of 3 NUL
     * terminated UTF-8 strings. First, the character name,
     * then the account name, and finally the subgroup name.
     * We're mainly interested in the account name...
     */
    name = agent_details.name;
    player.character = string(name);
    name += player.character.size() + 1;
    player.account = string(name);
    name += player.account.size() + 1;
    player.subgroup = string(name);

    /* The file seems to always store the account name with a
     * leading ':', we we'll remove it
     */
    if (player.account[0] == ':') {
        player.account.erase(0, 1);
    }

    details.players[player.addr] = player;
}

/**
 * parse_all_player_agents: extract all player data
 * @details: EVTC parsed data structure
 * @file: the EVTC file to read
 *
 * Loops over every agent and extracts all player data information from
 * the @file and stores it in @details.players
 */
static void
parse_all_player_agents(parsed_details& details, ifstream& file)
{
    unsigned int agent;

    for (agent = 0; agent < details.agent_count; agent++) {
        parse_player_agent(details, file, agent);
    }
}

/**
 * parse_boss_agent: extract boss agent details
 * @detals: EVTC parsed data structure
 * @file: the EVTC file to read
 *
 * Loops over every agent searching for the agent associated with
 * the boss creature, extracting useful information about the boss
 * and storing it in the @details structure.
 */
static void
parse_boss_agent(parsed_details& details, ifstream& file)
{
    unsigned int agent;

    for (agent = 0; agent < details.agent_count; agent++) {
        evtc_agent agent_details;
        uint16_t species_id;

        /* Copy the agent details from the file */
        get_agent_details(file, agent, agent_details);

        /* If this is a player agent, then skip it */
        if (agent_details.is_elite != EVTC_AGENT_NON_PLAYER_AGENT) {
            continue;
        }

        /* If this is a gadget, then skip it */
        if ((agent_details.prof & EVTC_AGENT_GADGET_AGENT) == EVTC_AGENT_GADGET_AGENT) {
            continue;
        }

        species_id = agent_details.prof & EVTC_AGENT_SPECIES_ID_MASK;

        if (species_id == details.boss_id) {
            details.boss_src_agent = agent_details.addr;
            break;
        }
    }
}

/**
 * parse_skill_count: extract the number of skills
 * @details: the EVTC parsed data structure
 * @file: the file to read from
 *
 * Extracts the skill count from the EVTC @file. Assumes that the
 * number of agents has already been extracted, so it reads the bytes
 * for the number of skill structures stored in the file.
 */
static void
parse_skill_count(parsed_details& details, ifstream& file)
{
    file.seekg(SEEKG_EVTC_SKILL_COUNT(details.agent_count));
    file.read((char *)&details.skill_count, sizeof(uint32_t));
}

/**
 * calculate_cbt_event_count: calculate number of combat events
 * @details: the EVTC parsed data structure
 * @file: the EVTC file to read from
 *
 * Unlike for agents and skills, the EVTC file format does not store
 * the number of combat events. Instead, this must be determined based
 * on the size of the file. It is calculated by determining the total
 * number of bytes the combat events take up using file seek positions,
 * divided by the cbtevent data structure defined by the EVTC file format.
 */
static void
calculate_cbt_event_count(parsed_details& details, ifstream& file)
{
    streampos cbtevent_pos, cbtevent_length;

    /* Seek to the beginning of the combat events */
    details.cbt_event_start = SEEKG_EVTC_FIRST_CBTEVENT(details.agent_count,
                                                        details.skill_count);
    file.seekg(details.cbt_event_start);
    cbtevent_pos = file.tellg();
    file.seekg(0, ios::end);
    cbtevent_length = file.tellg() - cbtevent_pos;

    details.cbt_event_count = cbtevent_length / EVTC_CBTEVENT_SIZE(details.revision);
}

/**
 * parse_reward_event: Parser for CBTS_REWARD events
 * @details: structure to hold parsed EVTC data
 * @event: the combat event to parse
 *
 * Checks if the event is a CBTS_REWARD event, which indicates that the
 * encounter was successfully completed. If the event matches, this parser
 * stores the success data in @details, and returns true. Otherwise it
 * returns false.
 */
static bool
parse_reward_event(parsed_details& details, evtc_cbtevent& event)
{
    if (event.is_statechange() == CBTS_REWARD) {
        /* A reward event indicates that the boss was killed successfully */
        details.encounter_success = true;
        details.precise_reward_time = event.time();
        return true;
    }

    return false;
}

/**
 * parse_logstart_event: Parser for CBTS_LOGSTART events
 * @details: structure to hold parsed EVTC data
 * @event: the combat event to parse
 *
 * Checks if the event is a CBTS_LOGSTART event which indicates the start time
 * according to the server. If the event matches, this parser stores the start
 * time in @details and returns true. Otherwise it returns false.
 */
static bool
parse_logstart_event(parsed_details& details, evtc_cbtevent& event)
{
    if (event.is_statechange() == CBTS_LOGSTART &&
        event.src_agent() == arcdps_src_agent) {
        /* The log start event indicates the server time when logs started */
        details.server_start = event.value();
        details.precise_start = event.time();
        return true;
    }

    return false;
}

/**
 * parse_logend_event: Parser for CBTS_LOGEND events
 * @details: structure to hold parsed EVTC data
 * @event: the combat event to parse
 *
 * Checks if the event is a CBTS_LOGEND event which indicates the end time
 * according to the server. If the event matches, this parser stores the end
 * time in @details and returns true. Otherwise it returns false.
 */
static bool
parse_logend_event(parsed_details& details, evtc_cbtevent& event)
{
    if (event.is_statechange() == CBTS_LOGEND &&
        event.src_agent() == arcdps_src_agent) {
        /* The log end event indicates the server time when logs ended */
        details.server_end = event.value();
        details.precise_logend_time = event.time();
        return true;
    }

    return false;
}

/**
 * parse_boss_maxhealth_event: Parser for CBTS_MAXHEALTHUPDATE events
 * @details: structure to hold parsed EVTC data
 * @event: the combat event to parse
 *
 * Checks if the event is a CBTS_MAXHEALTHUPDATE event that matches the
 * boss id we've found for the encounter. This will enable obtaining the
 * maximum health for the boss, which is useful for determining if an encounter
 * is a Challenge Mote variant. If the event matches, the parser stores the
 * maximum health in the @details and returns true. Otherwise it returns false.
 */
static bool
parse_boss_maxhealth_event(parsed_details& details, evtc_cbtevent& event)
{
    if (event.is_statechange() == CBTS_MAXHEALTHUPDATE &&
        event.src_agent() == details.boss_src_agent) {
        details.boss_maxhealth = event.dst_agent();
        return true;
    }

    return false;
}

/**
 * parse_guild_event: Parser for CBTS_GUILD events
 * @details: structure to hold parsed EVTC data
 * @event: the combat event to parse
 *
 * Checks if the event is a CBTS_GUILD event. If it is, and the src_agent
 * matches one of the player agent ids, store the 16-byte guid for that player.
 *
 * Returns true if the event was a CBTS_GUILD event, and false otherwise.
 */
static bool
parse_guild_event(parsed_details& details, evtc_cbtevent& event)
{
    if (event.is_statechange() == CBTS_GUILD) {
        auto it = details.players.find(event.src_agent());

        if (it != details.players.end()) {
            player_details& player = it->second;
            player.guid = event.guid();
        }

        return true;
    }

    return false;
}

/**
 * eventparser: typedef for combat event parsers
 * @details: the structure storing parsed EVTC data
 * @event: the combat event to parse
 *
 * A parser is expected to determine if this @event matches, and if so
 * extract data into the @details structure. Returning true indicates
 * that the event matched. Returning false indicates that the event did
 * not match this parser.
 */
using eventparser = bool (*)(parsed_details& details, evtc_cbtevent& event);

/* List of all current combat event parsers */
static const eventparser parsers[] = {
    parse_reward_event,
    parse_logstart_event,
    parse_logend_event,
    parse_boss_maxhealth_event,
    parse_guild_event,
};

static const int parsers_count = extent<decltype(parsers)>::value;

/**
 * parse_all_cbt_events: parse all combat events
 * @details: structure to hold parsed EVTC data
 * @file: the file to scan
 *
 * Loop through the entire list of combat events, checking each combat
 * event for information. Events are scanned by parsers one at a time until
 * a parser returns true.
 *
 * An event parser should return true if the event matched, and false otherwise.
 *
 * The events are scanned in order from beginning to end.
 */
static void
parse_all_cbt_events(parsed_details& details, ifstream& file)
{
    unsigned int event, parser;

    for (event = 0; event < details.cbt_event_count; event++) {
        evtc_cbtevent event_details = evtc_cbtevent(file, details.revision,
                                                    details.cbt_event_start, event);

        for (parser = 0; parser < parsers_count; parser++) {
            if (parsers[parser](details, event_details))
                break;
        }
    }
}

/**
 * detect_health_based_cm - Detect CM status based on maximum health
 * @details: structure to store EVTC data
 *
 * Using the maximum health data and boss info already gathered, update
 * the CM status depending on the maximum health found.
 */
static void
detect_health_based_cm(parsed_details& details)
{
    if (details.boss_info.cm == CM_HEALTH_BASED) {
        if (details.boss_maxhealth < details.boss_info.health_threshold) {
            details.boss_info.cm = CM_NO;
        } else {
            details.boss_info.cm = CM_YES;
        }
    }
}

/**
 * output_json - Output data in JSON format
 * @details: the details structure to output
 *
 * Convert the details structure into a JSON object which can be dumped to
 * the console.
 */
static void
output_json(parsed_details& details)
{
    json data = json::object();

    /* Track what version of simpleArcParse was used */
    data["simpleArcParse"]["version"] = version;

    /* ArcDPS data */
    data["header"]["arcdps_version"] = details.arc_header;
    data["header"]["revision"] = details.revision;

    /* Boss information */
    data["boss"]["name"] = details.boss_info.name;
    data["boss"]["location"] = details.boss_info.location;
    data["boss"]["id"] = details.boss_id;

    switch (details.boss_info.cm) {
    case CM_NO:
        data["boss"]["is_cm"] = "NO";
        break;
    case CM_YES:
        data["boss"]["is_cm"] = "YES";
        break;
    case CM_UNKNOWN:
        data["boss"]["is_cm"] = "UNKNOWN";
        break;
    case CM_HEALTH_BASED:
        data["boss"]["is_cm"] = "INVALID";
        break;
    }

    data["boss"]["maxhealth"] = details.boss_maxhealth;
    data["boss"]["success"] = details.encounter_success;
    data["boss"]["duration"] = (details.precise_end - details.precise_start);

    /* Local timestamps */
    data["local_time"]["start"] = details.precise_start;
    data["local_time"]["end"] = details.precise_end;
    data["local_time"]["last_event"] = details.precise_last_event;

    if (details.precise_reward_time) {
        data["local_time"]["reward"] = details.precise_reward_time;
    }

    if (details.precise_logend_time) {
        data["local_time"]["log_end"] = details.precise_logend_time;
    }

    /* server timestamps */
    data["server_time"]["start"] = details.server_start;
    data["server_time"]["end"] = details.server_end;

    /* Players */
    data["players"] = json::array();

    for (auto& kv : details.players) {
        auto& player = kv.second;
        json player_data = json::object();

        player_data["account"] = player.account;
        player_data["character"] = player.character;
        player_data["subgroup"] = player.subgroup;

        /* Add the Guild UID if we found it */
        if (player.guid.valid) {
            stringstream ss;

            ss << std::hex << std::uppercase;

            ss << setw(8) << setfill('0') << player.guid.data.p1 << "-";
            ss << setw(4) << setfill('0') << player.guid.data.p2 << "-";
            ss << setw(4) << setfill('0') << player.guid.data.p3 << "-";
            ss << setw(4) << setfill('0') << player.guid.data.p4 << "-";
            ss << setw(4) << setfill('0') << player.guid.data.p5;
            ss << setw(8) << setfill('0') << player.guid.data.p6;

            player_data["guid"] = ss.str().c_str();
        }

        data["players"] += player_data;
    }

    cout << data.dump(4) << std::endl;
}

/* Main control function */
int main(int argc, char *argv[])
{
    parsed_details details = {};
    string type, filename;
    ifstream evtc_file;
    unsigned int i;
    int err;

    /* argv[0] is the command name
     * argv[1] will hold the type of data to parse
     */
    if (argc < 2) {
        return -EINVAL;
    }

    type = string(argv[1]);

    err = -ENOTSUP;
    for (i = 0; i < valid_types_size; i++) {
        if (type == valid_types[i])
            err = 0;
    }
    if (err) {
        return err;
    }

    if (type == "version") {
        cout << version << endl;
        return 0;
    }

    /* Delay checking for filename until after we handle version */
    if (argc != 3) {
        return -E2BIG;
    }

    /* argv[2] will hold the file name to parse */
    filename = string(argv[2]);
    evtc_file.open(filename, ios::in | ios::binary);
    if (!evtc_file.is_open()) {
        cerr << "Failed to open " << filename << endl;
        return -ENOENT;
    }

    err = parse_header(details, evtc_file);
    if (err) {
        return err;
    }

    /* We must parse agent count first */
    parse_agent_count(details, evtc_file);

    /* Followed by the skill count */
    parse_skill_count(details, evtc_file);

    /* The number of combat events is not stored but we can calculate it */
    calculate_cbt_event_count(details, evtc_file);

    /* Extract data for each player in the encounter */
    parse_all_player_agents(details, evtc_file);

    /* Extract data about the boss agent */
    parse_boss_agent(details, evtc_file);

    /* Parse all of the combat events for relevant information */
    parse_all_cbt_events(details, evtc_file);

    /* Extract the local time of the last event */
    evtc_cbtevent event_details = evtc_cbtevent(evtc_file, details.revision,
                                                details.cbt_event_start,
                                                details.cbt_event_count - 1);
    details.precise_last_event = event_details.time();

    /* Detect CM status based on health */
    detect_health_based_cm(details);

    /* Use the most appropriate ending time available */
    if (details.precise_reward_time) {
        details.precise_end = details.precise_reward_time;
    } else if (details.precise_logend_time) {
        details.precise_end = details.precise_logend_time;
    } else {
        details.precise_end = details.precise_last_event;
    }

    /* Handle the various output requests */
    if (type == "header") {
        cout << details.arc_header << endl;
        cout << details.boss_info.name << endl;
        cout << details.boss_id << endl;
    } else if (type == "revision") {
        cout << +details.revision << endl;
    } else if (type == "players") {
        for (auto& kv : details.players) {
            auto& player = kv.second;
            cout << player.account << endl;
        }
    } else if (type == "success") {
        if (details.encounter_success) {
            cout << "SUCCESS" << endl;
        } else {
            cout << "FAILURE" << endl;
        }
    } else if (type == "start_time") {
        cout << details.server_start << endl;
    } else if (type == "end_time") {
        cout << details.server_end << endl;
    } else if (type == "boss_maxhealth") {
        cout << details.boss_maxhealth << endl;
    } else if (type == "is_cm") {
        switch (details.boss_info.cm) {
        case CM_NO:
            cout << "NO" << endl;
            break;
        case CM_YES:
            cout << "YES" << endl;
            break;
        case CM_UNKNOWN:
        case CM_HEALTH_BASED:
        default:
            cout << "UNKNOWN" << endl;
            break;
        }
    } else if (type == "duration") {
        if (details.precise_end >= details.precise_start)
            cout << (details.precise_end - details.precise_start) << endl;
    } else if (type == "local_start_time") {
        cout << details.precise_start << endl;
    } else if (type == "local_end_time") {
        cout << details.precise_end << endl;
    } else if (type == "location") {
        cout << details.boss_info.location << endl;
    } else if (type == "json") {
        output_json(details);
    }

    return 0;
}
