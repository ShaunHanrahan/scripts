import requests
import logging
import os
import sys
import time
from prometheus_client import start_http_server, Gauge, REGISTRY, CollectorRegistry, Info
from functools import reduce

class MapDataCollector:
    URL = "https://api.mozambiquehe.re/maprotation"
    def __init__(self, api_key: str, uid: str = None, player_name: str = None): # function signature
        self.uid = uid
        self.player_name = player_name
        self.headers = {
            "Authorization": api_key
        }

        # Data from MapRotation
        self.current_map_name = ''
        self.current_map_duration = 0
        self.current_map_remaining = 0
        self.next_map_name = ''
        self.next_map_start = 0
        self.next_map_duration = 0

    def populate_data(self):
        logging.debug("Collecting from: %s", self.URL)
        logging.debug("API KEY: %s", self.headers["Authorization"])

        map_rotation = requests.get(self.URL, headers=self.headers).json() # Convert json response to python object

        current_map_data = map_rotation["current"]
        next_map_data = map_rotation["next"]

        self.current_map_name = current_map_data["map"]
        self.next_map_name = next_map_data["map"]

        self.current_map_duration = current_map_data["DurationInMinutes"]
        self.next_map_duration = next_map_data["DurationInMinutes"]

        self.current_map_remaining = current_map_data["remainingMins"]
        self.next_map_start = next_map_data["start"]

class PlayerStatsCollector:
    URL = "https://api.mozambiquehe.re/bridge"
    def __init__(self, api_key: str, uid: str = None, player_name: str = None, platform: str = None): # function signature
        self.uid = uid
        self.platform = platform
        self.player_name = player_name
        self.headers = {
            "Authorization": api_key
        }

        # Data from global stats
        self.player_identifier = ''
        self.player_platform = ''
        self.level = 0
        self.next_level_percentage = 0
        self.banned = ''
        self.ban_duration = 0

        # Data from BR Ranking
        self.br_rank_name = ''
        self.br_rank_score = 0
        self.br_rank_div = 0

        # Data from Arena Rank
        self.arena_rank_name = ''
        self.arena_rank_score = 0
        self.arena_rank_div = 0

        # Data from BattlePass
        self.battle_pass_level = 0
        self.battle_pass_history = 0

        # Data from Realtime
        self.lobby_state = ''
        self.is_online = 0
        self.is_in_game = 0
        self.can_join = 0
        self.party_full = 0
        self.selected_legend = ''
        self.current_state = ''

        # Data from Current Legend
        self.current_legend_name = ''
        self.current_legend_br_kills = 0

        # Data from Player Total
        self.kills = 0
        self.kill_death_ratio = ''

        # Data from Mozambique
        self.mozambique_new_db = ''
        self.mozambique_cluster_server = ''

        # Data from API
        self.processing_time = 0

    def populate_data(self):
        logging.debug("Collecting from: %s", self.URL)
        logging.debug("API KEY: %s", self.headers["Authorization"])

        if self.player_name:
            player_stats = requests.get(self.URL, headers=self.headers, params={"player_name": self.player_name, "platform": self.platform}).json()
        else:
            player_stats = requests.get(self.URL, headers=self.headers, params={"uid": self.uid, "platform": self.platform}).json()

        player_info_data = player_stats["global"]
        player_realtime_data = player_stats["realtime"]
        player_current_legend_data = player_stats["legends"]["selected"]
        player_legends_kills = player_stats["legends"]["all"]
        player_mozambique_data = player_stats["mozambiquehere_internal"]
        player_total_data = player_stats["total"]
        api_data = player_stats["processingTime"]

        # Data from global stats
        self.player_identifier = player_info_data["name"]
        self.player_platform = player_info_data["platform"]
        self.level = player_info_data["level"]
        self.next_level_percentage = player_info_data["toNextLevelPercent"]
        self.banned = player_info_data["bans"]["isActive"]
        self.ban_duration = player_info_data["bans"]["remainingSeconds"]

        # Data from BR Ranking
        self.br_rank_name = player_info_data["rank"]["rankName"]
        self.br_rank_score = player_info_data["rank"]["rankScore"]
        self.br_rank_div = player_info_data["rank"]["rankDiv"]

        # Data from Arena Rank
        self.arena_rank_name = player_info_data["arena"]["rankName"]
        self.arena_rank_score = player_info_data["arena"]["rankScore"]
        self.arena_rank_div = player_info_data["arena"]["rankDiv"]

        # Data from BattlePass
        self.battle_pass_level = player_info_data["battlepass"]["level"]
        self.battle_pass_history = player_info_data["battlepass"]["history"]

        # Data from Realtime
        self.lobby_state = player_realtime_data["lobbyState"]
        self.is_online = player_realtime_data["isOnline"]
        self.is_in_game = player_realtime_data["isInGame"]
        self.can_join = player_realtime_data["canJoin"]
        self.party_full = player_realtime_data["partyFull"]
        self.selected_legend = player_realtime_data["selectedLegend"]
        self.current_state = player_realtime_data["currentState"]

        # Data from Current Legend
        self.current_legend_name = player_current_legend_data["LegendName"]
        self.current_legend_br_kills = player_current_legend_data["data"][0]["value"]

        # Data from All Legends
        self.all_legends_kills = {}

        # Generator Expression to extract kill value from all legends
        for legend_name, legend_info in player_legends_kills.items():
            if legend_name == 'Global':
                continue # skip
            if 'data' not in legend_info:
            # alternative: if not legend_info.get('data'):
                continue
            kill_value = next((item["value"] for item in legend_info['data'] if item['key'] == 'kills'), 0)
            if kill_value != 0:
                self.all_legends_kills[legend_name] = kill_value

        # Data from Player Total
        self.kills = player_total_data["kills"]
        self.kill_death_ratio = player_total_data["kd"]

        # Data from Mozambique
        self.mozambique_new_db = player_mozambique_data["isNewToDB"]
        self.mozambique_cluster_server = player_mozambique_data["clusterSrv"]

        # Data from API
        self.processing_time = api_data

class ApexCollector:
    def __init__(self, player_stats_collector: PlayerStatsCollector, map_stats_collector: MapDataCollector, registry: CollectorRegistry = REGISTRY):
        self.registry = registry

        # Define Prometheus metrics for map stats
        self.current_session_map = Info(
            'apex_current_map',
            'Name of the current map',
            registry=registry
        )

        self.current_session_duration = Gauge(
            'apex_current_map_duration_total',
            'Duration of the current map in minutes',
            ['map_name'],
            registry=registry
        )

        self.current_session_remaining = Gauge(
            'apex_current_map_remaining_total',
            'Time remaining of the current map in minutes',
            ['map_name'],
            registry=registry
        )

        self.next_session_map = Info(
            'apex_next_map',
            'Name of the next map',
            registry=registry
        )

        self.next_session_start = Gauge(
            'apex_next_map_start_total',
            'Start time of the next map in minutes',
            ['map_name'],
            registry=registry
        )

        self.next_session_duration = Gauge(
            'apex_next_map_duration_minutes',
            'Duration of the next map in minutes',
            ['map_name'],
            registry=registry
        )

        # Define Prometheus Metrics for Player Stats
        self.player_identifier = Info(
            'apex_player_identifier',
            'Name of the player',
            registry=registry
        )

        self.player_platform = Info(
            'player_platform',
            'Platform of the player',
            registry=registry
        )

        self.level = Gauge(
            'player_level',
            'Level of the player',
            registry=registry
        )

        self.next_level_percentage = Gauge(
            'player_next_level_percentage',
            'Next level percentage of the player',
            registry=registry
        )

        self.banned = Info(
            'player_banned',
            'Is the player banned',
            registry=registry
        )

        self.ban_duration = Gauge(
            'player_ban_duration',
            'Ban duration of the player',
            registry=registry
        )

        self.br_rank_name = Info(
            'player_br_rank_name',
            'BR Rank Name of the player',
            registry=registry
        )

        self.br_rank_score = Gauge(
            'player_br_rank_score',
            'BR Rank Score of the player',
            registry=registry
        )

        self.br_rank_div = Gauge(
            'player_br_rank_div',
            'BR Rank Division of the player',
            registry=registry
        )

        self.arena_rank_name = Info(
            'player_arena_rank_name',
            'Arena Rank Name of the player',
            registry=registry
        )

        self.arena_rank_score = Gauge(
            'player_arena_rank_score',
            'Arena Rank Score of the player',
            registry=registry
        )

        self.arena_rank_div = Gauge(
            'player_arena_rank_div',
            'Arena Rank Division of the player',
            registry=registry
        )

        self.battle_pass_level = Gauge(
            'player_battle_pass_level',
            'Battle Pass Level of the player',
            registry=registry
        )

        self.battle_pass_history = Gauge(
            'player_battle_pass_history',
            'Battle Pass History of the player',
            registry=registry
        )

        self.lobby_state = Info(
            'player_lobby_state',
            'Lobby state of the player',
            registry=registry
        )

        self.is_online = Gauge(
            'player_is_online',
            'Is the player online',
            registry=registry
        )

        self.is_in_game = Gauge(
            'player_is_in_game',
            'Is the player in a game',
            registry=registry
        )

        self.party_full = Info(
            'player_party_full',
            'Is the player in a party',
            registry=registry
        )

        self.selected_legend = Info(
            'player_selected_legend',
            'Name of the selected legend',
            registry=registry
        )

        self.current_state = Info(
            'player_current_state',
            'Current state of the player',
            registry=registry
        )

        self.kills = Gauge(
            'player_kills_total',
            'Total kills of the player',
            registry=registry
        )

        self.kill_death_ratio = Info(
            'player_kill_death_ratio',
            'Kill/Death Ratio of the player',
            registry=registry
        )

        self.mozambique_new_db = Info(
            'player_mozambique_new_db',
            'Is the player using the new database',
            registry=registry
        )

        self.mozambique_cluster_server = Info(
            'player_mozambique_cluster_server',
            'Cluster name presenting API',
            registry=registry
        )        

        self.processing_time = Gauge(
            'player_processing_time',
            'API Processing Time in milliseconds',
            registry=registry
        )

        self.player_stats_collector = player_stats_collector
        
        self.map_stats_collector = map_stats_collector

    def collect(self):
        self.player_stats_collector.populate_data()
        self.map_stats_collector.populate_data()

        print(self.map_stats_collector.current_map_name)
        self.current_session_map.info({'map_name': self.map_stats_collector.current_map_name})

if __name__ == "__main__":
    logging.basicConfig(
        format="%(asctime)s - %(levelname)s - %(message)s",
        level=logging.getLevelName(os.environ.get("LOG_LEVEL", "INFO").upper()),
        handlers=[logging.StreamHandler(sys.stdout)],
    )
    logging.info("Starting exporter")

    # Check required environment variables are set
    if not os.environ.get("USER_ID") and not os.environ.get("PLAYER_NAME"):
        logging.error("Either USER_ID or PLAYER_NAME must be set")
        sys.exit(1)

    if os.environ.get("USER_ID") and os.environ.get("PLAYER_NAME"):
        logging.error("Both USER_ID and PLAYER_NAME cannot be set")
        sys.exit(1)

    if not os.environ.get("API_KEY"):
        logging.error("API_KEY not set")
        sys.exit(1)

    credentials = {
        "uid": os.environ.get("USER_ID"),
        "player_name": os.environ.get("PLAYER_NAME"),
        "api_key": os.environ.get("API_KEY"),
    }

    player_stats_collector = PlayerStatsCollector(**credentials, platform=os.environ.get("PLATFORM").upper())
    map_stats_collector = MapDataCollector(**credentials)

    collector = ApexCollector(player_stats_collector, map_stats_collector)

    start_http_server(port=8000)

    while True:
        collector.collect()
        time.sleep(15)
