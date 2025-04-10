import networkx as nx
from networkx.algorithms.connectivity import minimum_st_node_cut
import matplotlib.pyplot as plt

graphs = [
    {
        "name": "Single cluster", 
        "v": 5,                                                         # Number of vertices, numbered from 1- value here
        "e": [("v1", "v2"), ("v1", "v3"), ("v2", "v4"), ("v4", "v5")],  # Edges
        "s": ["s1", "s2", "s3", "s4", "s5"],                            # Services in the system
        "a": [["s1"], ["s2"], ["s3"], ["s4"], ["s5"]],                  # Services provided at each node
        "n": [["s2", "s3"], ["s4"], [], ["s5"], []]                     # Dependencies of each node
    },
    {
        "name": "Multi cluster", 
        "v": 15,                                # Number of vertices, numbered from 1- value here
        "s": ["s1", "s2", "s3", "s4", "s5"],    # Services in the system
        # Services provided at each node
        "a": [["s1"], ["s2"], ["s3"], ["s4"], ["s5"], ["s1"], ["s2"], ["s3"], ["s4"], ["s5"], ["s1"], ["s2"], ["s3"], ["s4"], ["s5"]],         
        # Dependencies of each node
        "n": [["s2", "s3"], ["s4"], [], ["s5"], [], ["s2", "s3"], ["s4"], [], ["s5"], [], ["s2", "s3"], ["s4"], [], ["s5"], []],        
        # Edges:
        "e":  [("v1", "v2"), ("v1", "v7"), ("v1", "v12"), ("v1", "v3"), ("v1", "v8"), ("v1", "v13"),
         ("v6", "v2"), ("v6", "v7"), ("v6", "v12"), ("v6", "v3"), ("v6", "v8"), ("v6", "v13"),
         ("v11", "v2"), ("v11", "v7"), ("v11", "v12"), ("v11", "v3"), ("v11", "v8"), ("v11", "v13"),
         ("v2", "v4"), ("v2", "v9"), ("v2", "v14"),
         ("v7", "v4"), ("v7", "v9"), ("v7", "v14"),
         ("v12", "v4"), ("v12", "v9"), ("v12", "v14"),
         ("v4", "v5"), ("v4", "v10"), ("v4", "v15"),
         ("v9", "v5"), ("v9", "v10"), ("v9", "v15"),
         ("v14", "v5"), ("v14", "v10"), ("v14", "v15")]
    }
]

def construct_auxiliary_graph(graph: dict, service: str) -> tuple[nx.Graph, str]:
    G = nx.Graph(graph["e"])
    new_node = "v"+str(graph["v"]+1)
    G.add_node(new_node)

    nodes_providing_service = []
    for i in range(1,graph["v"]+1):
        if service in graph["a"][i-1]:
            nodes_providing_service.append("v"+str(i))

    new_edges = [(new_node, node) for node in nodes_providing_service]
    G.add_edges_from(new_edges)


    for u,v in G.edges:
        if (u in nodes_providing_service) and (v in nodes_providing_service):
            G.remove_edge(u,v)

    return G, new_node

def get_demand_points(graph: dict, service: str) -> list:
    demand_points = []
    for i in range(1, graph["v"]):
        if service in graph["n"][i-1]:
            demand_points.append("v"+str(i))
    print(f"Demand points for {service} in {graph["name"]} are {demand_points}")
    return demand_points

def get_min_sv_edge_cutset(s: str, t: str, G: nx.Graph) -> float:
   cut_weight = len(minimum_st_node_cut(G, s, t))
   print(f"Min node S-V cutset for {s}, {t} is {cut_weight}")
   return cut_weight

def find_resilience_service(graph: dict, service: str) -> float:
    G, s = construct_auxiliary_graph(graph, service)
    D = get_demand_points(graph, service)
    if len(D) == 0:
        return None
    min_sv_edge_cutsets = []
    for t in D:
        min_sv_edge_cutsets.append(get_min_sv_edge_cutset(s, t, G))
    return min(min_sv_edge_cutsets)

def find_edge_resilience(graph: dict) -> float:
    min_service_resiliences = []
    for service in graph["s"]:
        service_resilience = find_resilience_service(graph, service)
        if service_resilience is not None:
            min_service_resiliences.append(service_resilience)
    return min(min_service_resiliences)

for graph in graphs:
    graph_edge_resilience = find_edge_resilience(graph)
    print(f"Graph node resilience for {graph["name"]} is {graph_edge_resilience}")