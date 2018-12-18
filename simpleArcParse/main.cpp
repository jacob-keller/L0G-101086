/* SPDX-License-Identifier: BSD-3-Clause
 * Copyright 2018 Jacob Keller. All rights reserved.
 *
 * Some structure definitions and names taken from https://www.deltaconnected.com/arcdps/evtc
 */
#include <iostream>
#include <fstream>
#include <string>
#include <sstream>
#include <cstring>
#include <cerrno>
#include <cctype>
#include <vector>
#include <type_traits>

using namespace std;

/* iff */
enum iff {
	IFF_FRIEND, // green vs green, red vs red
	IFF_FOE, // green vs red
	IFF_UNKNOWN // something very wrong happened
};

/* combat result (physical) */
enum cbtresult {
	CBTR_NORMAL, // good physical hit
	CBTR_CRIT, // physical hit was crit
	CBTR_GLANCE, // physical hit was glance
	CBTR_BLOCK, // physical hit was blocked eg. mesmer shield 4
	CBTR_EVADE, // physical hit was evaded, eg. dodge or mesmer sword 2
	CBTR_INTERRUPT, // physical hit interrupted something
	CBTR_ABSORB, // physical hit was "invlun" or absorbed eg. guardian elite
	CBTR_BLIND, // physical hit missed
	CBTR_KILLINGBLOW // physical hit was killing hit
};

/* combat activation */
enum cbtactivation {
	ACTV_NONE, // not used - not this kind of event
	ACTV_NORMAL, // activation without quickness
	ACTV_QUICKNESS, // activation with quickness
	ACTV_CANCEL_FIRE, // cancel with reaching channel time
	ACTV_CANCEL_CANCEL, // cancel without reaching channel time
	ACTV_RESET // animation completed fully
};

/* combat state change */
enum cbtstatechange {
	CBTS_NONE, // not used - not this kind of event
	CBTS_ENTERCOMBAT, // src_agent entered combat, dst_agent is subgroup
	CBTS_EXITCOMBAT, // src_agent left combat
	CBTS_CHANGEUP, // src_agent is now alive
	CBTS_CHANGEDEAD, // src_agent is now dead
	CBTS_CHANGEDOWN, // src_agent is now downed
	CBTS_SPAWN, // src_agent is now in game tracking range
	CBTS_DESPAWN, // src_agent is no longer being tracked
	CBTS_HEALTHUPDATE, // src_agent has reached a health marker. dst_agent = percent * 10000 (eg. 99.5% will be 9950)
	CBTS_LOGSTART, // log start. value = server unix timestamp **uint32**. buff_dmg = local unix timestamp. src_agent = 0x637261 (arcdps id)
	CBTS_LOGEND, // log end. value = server unix timestamp **uint32**. buff_dmg = local unix timestamp. src_agent = 0x637261 (arcdps id)
	CBTS_WEAPSWAP, // src_agent swapped weapon set. dst_agent = current set id (0/1 water, 4/5 land)
	CBTS_MAXHEALTHUPDATE, // src_agent has had it's maximum health changed. dst_agent = new max health
	CBTS_POINTOFVIEW, // src_agent will be agent of "recording" player
	CBTS_LANGUAGE, // src_agent will be text language
	CBTS_GWBUILD, // src_agent will be game build
	CBTS_SHARDID, // src_agent will be sever shard id
	CBTS_REWARD, // src_agent is self, dst_agent is reward id, value is reward type. these are the wiggly boxes that you get
	CBTS_BUFFINITIAL // combat event that will appear once per buff per agent on logging start (zero duration, buff==18)
};

/* combat buff remove type */
enum cbtbuffremove {
	CBTB_NONE, // not used - not this kind of event
	CBTB_ALL, // all stacks removed
	CBTB_SINGLE, // single stack removed. disabled on server trigger, will happen for each stack on cleanse
	CBTB_MANUAL, // autoremoved by ooc or allstack (ignore for strip/cleanse calc, use for in/out volume)
};

/* custom skill ids */
enum cbtcustomskill {
	CSK_RESURRECT = 1066, // not custom but important and unnamed
	CSK_BANDAGE = 1175, // personal healing only
	CSK_DODGE = 65001 // will occur in is_activation==normal event
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
	int16_t toughness;
	int16_t concentration;
	int16_t healing;
	int16_t pad1;
	int16_t condition;
	int16_t pad2;
	char name[64];
};

/* define skill */
struct evtc_skill {
	int32_t id;
	char name[64];
};

/* combat event */
struct evtc_cbtevent_v0 {
	uint64_t time; /* timegettime() at time of event */
	uint64_t src_agent; /* unique identifier */
	uint64_t dst_agent; /* unique identifier */
	int32_t value; /* event-specific */
	int32_t buff_dmg; /* estimated buff damage. zero on application event */
	uint16_t overstack_value; /* estimated overwritten stack duration for buff application */
	uint16_t skillid; /* skill id */
	uint16_t src_instid; /* agent map instance id */
	uint16_t dst_instid; /* agent map instance id */
	uint16_t src_master_instid; /* master source agent map instance id if source is a minion/pet */
	uint8_t iss_offset; /* internal tracking. garbage */
	uint8_t iss_offset_target; /* internal tracking. garbage */
	uint8_t iss_bd_offset; /* internal tracking. garbage */
	uint8_t iss_bd_offset_target; /* internal tracking. garbage */
	uint8_t iss_alt_offset; /* internal tracking. garbage */
	uint8_t iss_alt_offset_target; /* internal tracking. garbage */
	uint8_t skar; /* internal tracking. garbage */
	uint8_t skar_alt; /* internal tracking. garbage */
	uint8_t skar_use_alt; /* internal tracking. garbage */
	uint8_t iff; /* from iff enum */
	uint8_t buff; /* buff application, removal, or damage event */
	uint8_t result; /* from cbtresult enum */
	uint8_t is_activation; /* from cbtactivation enum */
	uint8_t is_buffremove; /* buff removed. src=relevant, dst=caused it (for strips/cleanses). from cbtr enum */
	uint8_t is_ninety; /* source agent health was over 90% */
	uint8_t is_fifty; /* target agent health was under 50% */
	uint8_t is_moving; /* source agent was moving */
	uint8_t is_statechange; /* from cbtstatechange enum */
	uint8_t is_flanking; /* target agent was not facing source */
	uint8_t is_shields; /* all or part damage was vs barrier/shield */
	uint8_t result_local; /* internal tracking. garbage */
	uint8_t ident_local; /* internal tracking. garbage */
};

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
 * This macro is provided as a convenient way to define accessors for the most common
 * fields that do not need any special handling between versions. Otherwise
 * we would end up duplicating this boiler plate revision version check many times.
 */
#define CBTEVENT_ACCESSOR(type, field)                          \
    type field() {                                              \
        if (revision == cbtevent_revision_v0)                   \
            return (type)(raw.v0.field);                        \
        else if (revision == cbtevent_revision_v1)              \
            return (type)(raw.v1.field);                        \
        else                                                    \
            throw "Invalid cbtevent revision";                  \
    }

/* Abstraction of the various evtc_cbtevent versions */
class evtc_cbtevent {
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
evtc_cbtevent::evtc_cbtevent(ifstream& file, uint8_t revision,
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
    "header",
    "revision",
    "players",
    "success",
    "start_time",
    "end_time",
    "boss_maxhealth",
    "is_cm",
    "duration",
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

static const uint16_t vale_guardian_id  = 0x3C4E;
static const uint16_t gorseval_id       = 0x3C45;
static const uint16_t sabetha_id        = 0x3C0F;
static const uint16_t slothasor_id      = 0x3EFB;
static const uint16_t trio_id1          = 0x3ED8;
static const uint16_t trio_id2          = 0x3F09;
static const uint16_t trio_id3          = 0x3EFD;
static const uint16_t matthias_id       = 0x3EF3;
static const uint16_t keep_construct_id = 0x3F6B;
static const uint16_t xera_id1          = 0x3F76;
static const uint16_t xera_id2          = 0x3F9E;
static const uint16_t cairn_id          = 0x432A;
static const uint16_t overseer_id       = 0x4314;
static const uint16_t samarog_id        = 0x4324;
static const uint16_t deimos_id         = 0x4302;
static const uint16_t horror_id         = 0x4d37;
static const uint16_t dhuum_id          = 0x4bfa;

/* Possible wing6 boss ids */
static const uint16_t conjured_amalgamate_id = 43974;
static const uint16_t nikare_id              = 21105;
static const uint16_t kenut_id               = 21089;
static const uint16_t qadim_id               = 20934;

/* Fractal 99 CM boss encounters */
static const uint16_t mama_cm_id        = 0x427d;
static const uint16_t siax_cm_id        = 0x4284;
static const uint16_t ensolyss_cm_id    = 0x4234;

/* Fractal 100 CM boss encounters */
static const uint16_t skorvald_cm_id    = 0x44e0;
static const uint16_t artsariiv_cm_id   = 0x461d;
static const uint16_t arkk_cm_id        = 0x455f;

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
};

enum is_boss_cm {
    CM_UNKNOWN,
    CM_NO,
    CM_YES,
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
    string boss_name;
    uint64_t boss_src_agent;
    uint64_t boss_maxhealth;
    enum is_boss_cm is_cm;
    uint32_t server_start;
    uint32_t server_end;
    uint64_t precise_start;
    uint64_t precise_end;
    bool encounter_success;
    vector<player_details> players;
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

    switch (details.boss_id) {
    case vale_guardian_id:
        details.boss_name = "Vale Guardian";
        break;
    case gorseval_id:
        details.boss_name = "Gorseval";
        break;
    case sabetha_id:
        details.boss_name = "Sabetha";
        break;
    case slothasor_id:
        details.boss_name = "Slothasor";
        break;
    case trio_id1:
    case trio_id2:
    case trio_id3:
        details.boss_name = "Bandit Trio";
        break;
    case matthias_id:
        details.boss_name = "Matthias";
        break;
    case keep_construct_id:
        details.boss_name = "Keep Construct";
        break;
    case xera_id1:
    case xera_id2:
        details.boss_name = "Xera";
        break;
    case cairn_id:
        details.boss_name = "Cairn";
        break;
    case overseer_id:
        details.boss_name = "Mursaat Overseer";
        break;
    case samarog_id:
        details.boss_name = "Samarog";
        break;
    case deimos_id:
        details.boss_name = "Deimos";
        break;
    case horror_id:
        details.boss_name = "Soulless Horror";
        break;
    case dhuum_id:
        details.boss_name = "Dhuum";
        break;
    case mama_cm_id:
        details.boss_name = "MAMA (CM)";
        break;
    case siax_cm_id:
        details.boss_name = "Siax (CM)";
        break;
    case ensolyss_cm_id:
        details.boss_name = "Ensolyss (CM)";
        break;
    case skorvald_cm_id:
        details.boss_name = "Skorvald the Shattered (CM)";
        break;
    case artsariiv_cm_id:
        details.boss_name = "Artsariiv (CM)";
        break;
    case arkk_cm_id:
        details.boss_name = "Arkk (CM)";
        break;
    case conjured_amalgamate_id:
        details.boss_name = "Conjured Amalgamate";
        break;
    case nikare_id:
        details.boss_name = "Largos Twins";
        break;
    case kenut_id:
        /* This shouldn't end up in a real evtc file, but for completeness sake... */
        details.boss_id = nikare_id;
        details.boss_name = "Largos Twins";
        break;
    case qadim_id:
        details.boss_name = "Qadim";
        break;

    default:
        std::stringstream ss;
        ss << "Unknown encounter " << details.boss_id;
        details.boss_name = std::move(ss.str().c_str());
        break;
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
    evtc_agent agent_details;
    player_details player;
    char *name;

    /* Copy the agent details from the file */
    get_agent_details(file, agent, agent_details);

    if (agent_details.is_elite == EVTC_AGENT_NON_PLAYER_AGENT) {
        return;
    }

    /* The EVTC format stores the name as a sequence of 3 NUL
     * terminated UTF-8 strings. First, the character name,
     * then the account name, and finally the subgroup name.
     * We're mainly interested in the account name...
     */
    name = agent_details.name;
    player.character = string(name);
    name += player.character.size() + 1;
    player.account = string(name);

    /* The file seems to always store the account name with a
     * leading ':', we we'll remove it
     */
    if (player.account[0] == ':') {
        player.account.erase(0, 1);
    }

    details.players.push_back(player);
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
        details.precise_end = event.time();
        return true;
    }

    return false;
}

/**
 * parse_precise_end: Parser for precise time encounter end
 * @details: structure to hold parsed EVTC data
 * @event: the combat event to parse
 *
 * Searches for the precise time when the encounter ended. This is either
 * the time() at CBTS_REWARD, if the encounter is successful. Otherwise, we
 * just fall back to the CBTS_LOGEND time(). This should be more precise
 * than simply subtracting logend from logstart, as events can continue appearing
 * in the log file after the boss is dead.
 *
 * Returns true if the CBTS_REWARD event was found, otherwise false.
 */
static bool
parse_precise_end(parsed_details& details, evtc_cbtevent& event)
{
    if (event.is_statechange() == CBTS_LOGEND &&
        event.src_agent() == arcdps_src_agent) {

        /* Only assign the precise_end time if it hasn't yet been found */
        if (!details.precise_end)
            details.precise_end = event.time();

        /* Keep searching for the CBTS_REWARD event */
        return false;
    }

    if (event.is_statechange() == CBTS_REWARD) {
        details.precise_end = event.time();
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
    parse_precise_end,
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
 * The intent of this function is to extract all possible data we currently
 * understand from the combat events.
 *
 * This function is currently unused.
 */
static void __attribute__((unused))
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
 * parse_first_matching_event: parse combat events with a given parser
 * @details: structure to store EVTC data
 * @file: the file to scan
 * @parser: the parser to use
 *
 * Scan through the list of combat events from the beginning, checking each
 * event with the @parser. The first time @parser returns true, stop scanning.
 *
 * This function is intended to find a single combat event near the start of the
 * events, such as the log start time.
 */
static void
parse_first_matching_event(parsed_details& details, ifstream& file, eventparser parser)
{
    unsigned int event;
    for (event = 0; event < details.cbt_event_count; event++) {
        evtc_cbtevent event_details = evtc_cbtevent(file, details.revision,
                                                    details.cbt_event_start,
                                                    event);

        if (parser(details, event_details))
            break;
    }
}

/**
 * parse_last_matching_event: parse combat events with a given parser
 * @details: structure to store EVTC data
 * @file: the file to scan
 * @parser: the parser to use
 *
 * Scan through the list of combat events from the end, checking each event
 * with the @parser. The first time @parser returns true, stop scanning.
 *
 * This function is intended to find a single combat event near the end of
 * the events, such as the reward chests indicating success.
 */
static void
parse_last_matching_event(parsed_details& details, ifstream& file, eventparser parser)
{
    unsigned int event;
    for (event = details.cbt_event_count; event-- > 0;) {
        evtc_cbtevent event_details = evtc_cbtevent(file, details.revision,
                                                    details.cbt_event_start,
                                                    event);

        if (parser(details, event_details))
            break;
    }
}

/**
 * detect_challenge_mote: Detect if the encounter was a challenge mote
 * @details: structure to store EVTC data
 * @file: the file to scan
 *
 * Using data already scanned about the encounter, determine if the evtc
 * file represents a challenge mote encounter or not. If we are unable
 * to determine this accurately, set is_cm to CM_UNKNOWN.
 */
static void
detect_challenge_mote(parsed_details& details, ifstream& file)
{
    if (details.boss_id == nikare_id) {
        if (details.boss_maxhealth > 18000000) {
            details.is_cm = CM_YES;
        } else {
            details.is_cm = CM_NO;
        }
    } else if (details.boss_id == overseer_id) {
        if (details.boss_maxhealth > 25000000) {
            details.is_cm = CM_YES;
        } else {
            details.is_cm = CM_NO;
        }
    } else if (details.boss_id == deimos_id) {
        if (details.boss_maxhealth > 40000000) {
            details.is_cm = CM_YES;
        } else {
            details.is_cm = CM_NO;
        }
    } else if (details.boss_id == samarog_id) {
        if (details.boss_maxhealth > 30000000) {
            details.is_cm = CM_YES;
        } else {
            details.is_cm = CM_NO;
        }
    } else if (details.boss_id == dhuum_id) {
        if (details.boss_maxhealth > 35000000) {
            details.is_cm = CM_YES;
        } else {
            details.is_cm = CM_NO;
        }
    } else if (details.boss_id == qadim_id) {
        if (details.boss_maxhealth > 21000000) {
            details.is_cm = CM_YES;
        } else {
            details.is_cm = CM_NO;
        }
    } else if (details.boss_id == cairn_id) {
        /* Cairn CM is detected by checking for a specific skill */
        details.is_cm = CM_UNKNOWN;
    } else if (details.boss_id == horror_id) {
        /* Soulless Horor CM is detected by checking the necrosis debuff */
        details.is_cm = CM_UNKNOWN;
    } else if (details.boss_id == conjured_amalgamate_id) {
        /* Conjured Amalgamate is checking for a specific buff */
        details.is_cm = CM_UNKNOWN;
    } else {
        /* Other encounters do not have challenge motes */
        details.is_cm = CM_NO;
    }
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
        cout << "v1.3.1" << endl;
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

    /* Some data is relatively expensive to extract, so only do so if we need it */
    if (type == "players") {
        /* Extract data for each player in the encounter */
        parse_all_player_agents(details, evtc_file);
    } else if (type == "success") {
        parse_last_matching_event(details, evtc_file, parse_reward_event);
    } else if (type == "start_time") {
        parse_first_matching_event(details, evtc_file, parse_logstart_event);
    } else if (type == "end_time") {
        parse_last_matching_event(details, evtc_file, parse_logend_event);
    } else if (type == "boss_maxhealth" || type == "is_cm") {
        parse_boss_agent(details, evtc_file);
        parse_first_matching_event(details, evtc_file, parse_boss_maxhealth_event);
    } else if (type == "duration") {
        parse_first_matching_event(details, evtc_file, parse_logstart_event);
        parse_last_matching_event(details, evtc_file, parse_precise_end);
    }

    if (type == "is_cm") {
        detect_challenge_mote(details, evtc_file);
    }

    if (type == "header") {
        cout << details.arc_header << endl;
        cout << details.boss_name << endl;
        cout << details.boss_id << endl;
    } else if (type == "revision") {
        cout << +details.revision << endl;
    } else if (type == "players") {
        for (auto& player : details.players) {
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
        switch (details.is_cm) {
        case CM_NO:
            cout << "NO" << endl;
            break;
        case CM_YES:
            cout << "YES" << endl;
            break;
        case CM_UNKNOWN:
        default:
            cout << "UNKNOWN" << endl;
            break;
        }
    } else if (type == "duration") {
        if (details.precise_end >= details.precise_start)
            cout << (details.precise_end - details.precise_start) << endl;
    }

    return 0;
}
