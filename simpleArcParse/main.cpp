/* SPDX-License-Identifier: BSD-3-Clause
 * Copyright 2018 Jacob Keller. All rights reserved.
 *
 * Some structure definitions and names taken from https://www.deltaconnected.com/arcdps/evtc
 */
#include <iostream>
#include <fstream>
#include <string>
#include <cstring>
#include <cerrno>
#include <cctype>
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
typedef struct evtc_agent {
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
} evtc_agent;

/* define skill */
typedef struct evtc_skill {
	int32_t id;
	char name[64];
} evtc_skill;

/* combat event */
typedef struct evtc_cbtevent {
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
} evtc_cbtevent;

static const string validTypes[] = {
    "header",
    "players",
    "success",
    "start_time",
};

static const int validTypesSize = extent<decltype(validTypes)>::value;

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
static uint32_t EVTC_CBTEVENT_SIZE = sizeof(evtc_cbtevent);

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

static const uint64_t arcdps_src_agent = 0x637261;

/* is_elite value indicating a non-player object */
static const uint32_t EVTC_AGENT_NON_PLAYER_AGENT = 0xffffffff;

static int
parseHeader(ifstream& file, bool printHeader)
{
    uint16_t area_id;
    char header[16];

    /* The evtc file has a 16 byte header. It consists of
     * 4 bytes containing "EVTC", followed by 8 bytes
     * with a YYYYMMDD representing the arcdps build,
     * followed by a NUL byte, followed by 2 bytes holding
     * the area encounter id, followed by another NUL
     */

    file.seekg(SEEKG_EVTC_HEADER);
    file.read(header, 16);

    /* Make sure we have the 4 bytes of EVTC */
    if (strncmp(header, "EVTC", 4)) {
        return -EINVAL;
    }

    /* Make sure the version is a number */
    for (int i = 4; i < 12; i++) {
        if (!isdigit(header[i])) {
            return -EINVAL;
        }
    }

    /* Make sure there is a NUL following the YYYYMMDD */
    if (header[12] != '\0') {
        return -EINVAL;
    }

    /* Make sure there is a NUL in the byte following the area id */
    if (header[15] != '\0') {
        return -EINVAL;
    }

    /* extract the area id */
    memcpy(&area_id, &header[13], sizeof(area_id));

    if (printHeader) {
        cout << header << endl;
        switch (area_id) {
        case vale_guardian_id:
            cout << "Vale Guardian" << endl;
            break;
        case gorseval_id:
            cout << "Gorseval" << endl;
            break;
        case sabetha_id:
            cout << "Sabetha" << endl;
            break;
        case slothasor_id:
            cout << "Slothasor" << endl;
            break;
        case trio_id1:
        case trio_id2:
        case trio_id3:
            cout << "Bandit Trio" << endl;
            break;
        case matthias_id:
            cout << "Matthias" << endl;
            break;
        case keep_construct_id:
            cout << "Keep Construct" << endl;
            break;
        case xera_id1:
        case xera_id2:
            cout << "Xera" << endl;
            break;
        case cairn_id:
            cout << "Cairn" << endl;
            break;
        case overseer_id:
            cout << "Mursaat Overseer" << endl;
            break;
        case samarog_id:
            cout << "Samarog" << endl;
            break;
        case deimos_id:
            cout << "Deimos" << endl;
            break;
        case horror_id:
            cout << "Soulless Horror" << endl;
            break;
        case dhuum_id:
            cout << "Dhuum" << endl;
            break;
        default:
            cout << "Unknown encounter 0x" << hex << area_id << endl;
            break;
        }
    }

    return 0;
}

static uint32_t
parseAgentCount(ifstream& file)
{
    uint32_t agentCount = 0;

    file.seekg(SEEKG_EVTC_AGENT_COUNT);
    file.read((char *)&agentCount, sizeof(uint32_t));

    return agentCount;
}

static void
getAgentDetails(ifstream& file, uint32_t agent, evtc_agent& agentDetails)
{
    uint32_t fdindex = SEEKG_EVTC_FIRST_AGENT;

    fdindex += agent * sizeof(evtc_agent);

    file.seekg(fdindex);
    file.read((char *)&agentDetails, sizeof(evtc_agent));
}

static void
parsePlayerAgent(ifstream& file, unsigned int agent)
{
    evtc_agent agentDetails;
    string characterName;
    string accountName;
    char *name;

    /* Copy the agent details from the file */
    getAgentDetails(file, agent, agentDetails);

    if (agentDetails.is_elite == EVTC_AGENT_NON_PLAYER_AGENT) {
        return;
    }

    /* The EVTC format stores the name as a sequence of 3 NUL
     * terminated UTF-8 strings. First, the character name,
     * then the account name, and finally the subgroup name.
     * We're mainly interested in the account name...
     */
    name = agentDetails.name;
    characterName = string(name);
    name += characterName.size() + 1;
    accountName = string(name);

    /* The file seems to always store the account name with a
     * leading ':', we we'll remove it
     */
    if (accountName[0] == ':') {
        accountName.erase(0, 1);
    }

    cout << accountName << endl;
}

static uint32_t
parseSkillCount(ifstream& file, uint32_t agentCount)
{
    uint32_t skillCount = 0;

    file.seekg(SEEKG_EVTC_SKILL_COUNT(agentCount));
    file.read((char *)&skillCount, sizeof(uint32_t));

    return skillCount;
}

static uint32_t
calculateCbtEventCount(ifstream& file, uint32_t agentCount, uint32_t skillCount)
{
    streampos cbtevent_pos, cbtevent_length;

    /* Seek to the beginning of the combat events */
    file.seekg(SEEKG_EVTC_FIRST_CBTEVENT(agentCount, skillCount));
    cbtevent_pos = file.tellg();
    file.seekg(0, ios::end);
    cbtevent_length = file.tellg() - cbtevent_pos;

    return cbtevent_length / EVTC_CBTEVENT_SIZE;
}

static void
getCbtEventDetails(ifstream& file, streampos cbtEventStart, uint32_t cbtevent, evtc_cbtevent& cbtEventDetails)
{
    uint32_t fdindex = cbtEventStart;

    fdindex += cbtevent * sizeof(evtc_cbtevent);

    file.seekg(fdindex);
    file.read((char *)&cbtEventDetails, sizeof(evtc_cbtevent));
}

static bool
parseRewardCbtEvent(ifstream& file, streampos cbtEventStart, uint32_t cbtevent)
{
    evtc_cbtevent cbtEventDetails;

    getCbtEventDetails(file, cbtEventStart, cbtevent, cbtEventDetails);

    /* return code indicates that we found proof of rewards */
    if (cbtEventDetails.is_statechange == CBTS_REWARD) {
        cout << "SUCCESS" << endl;
        return true;
    }

    return false;
}
static bool
parseStartTimeCbtEvent(ifstream& file, streampos cbtEventStart, uint32_t cbtevent)
{
    evtc_cbtevent cbtEventDetails;

    getCbtEventDetails(file, cbtEventStart, cbtevent, cbtEventDetails);

    /* return code indicates that we found proof of rewards */
    if (cbtEventDetails.is_statechange == CBTS_LOGSTART &&
        cbtEventDetails.src_agent == arcdps_src_agent) {
        cout << cbtEventDetails.value << endl;
        return true;
    }

    return false;
}

int main(int argc, char *argv[])
{
    string type, filename;
    ifstream evtc_file;
    streampos cbtEventStart;
    uint32_t agentCount, skillCount, cbtEventCount;
    unsigned int i;
    int err;

    /* argv[0] is the command name
     * argv[1] will hold the type of data to parse
     * argv[2] will hold the file name to parse
     */
    if (argc != 3) {
        return -E2BIG;
    }

    type = string(argv[1]);
    filename = string(argv[2]);

    err = -ENOTSUP;
    for (i = 0; i < validTypesSize; i++) {
        if (type == validTypes[i])
            err = 0;
    }
    if (err) {
        return err;
    }

    evtc_file.open(filename, ios::in | ios::binary);
    if (!evtc_file.is_open()) {
        cerr << "Failed to open " << filename << endl;
        return -ENOENT;
    }

    err = parseHeader(evtc_file, (type == "header"));
    if (err) {
            return err;
    }

    agentCount = parseAgentCount(evtc_file);

    if (type == "players") {
        for (i = 0; i < agentCount; i++) {
            parsePlayerAgent(evtc_file, i);
        }
    }

    skillCount = parseSkillCount(evtc_file, agentCount);

    cbtEventCount = calculateCbtEventCount(evtc_file, agentCount, skillCount);

    cbtEventStart = SEEKG_EVTC_FIRST_CBTEVENT(agentCount, skillCount);

    if (type == "success") {
        bool foundIndicator = false;
        for (i = cbtEventCount; i-- > 0; ) {
            foundIndicator = parseRewardCbtEvent(evtc_file, cbtEventStart, i);
            if (foundIndicator) {
                break;
            }
        }
        if (!foundIndicator) {
            /* If no indicator was found, assume failure */
            cout << "FAILURE" << endl;
        }
    }

    if (type == "start_time") {
        bool foundIndicator = false;
        for (i = 0; i < cbtEventCount; i++) {
            foundIndicator = parseStartTimeCbtEvent(evtc_file, cbtEventStart, i);
            if (foundIndicator) {
                break;
            }
        }
    }

    return 0;
}
