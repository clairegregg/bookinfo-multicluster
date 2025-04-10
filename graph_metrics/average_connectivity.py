import networkx as nx
from networkx.algorithms import approximation as approx
from scipy.special import binom

graphs = [
    {
        "name": "Multi cluster", 
        "nodes": ["PP", "RV", "DT", "RA", "DB"], 
        "edges": [("PP", "RV"), ("PP", "DT"), ("RV", "RA"), ("RA", "DB")],
    },
    {
        "name": "Multi cluster", 
        "nodes": ["PP1", "PP2", "PP3", "RV1", "RV2", "RV3", "DT1", "DT2", "DT3","RA1", "RA2", "RA3", "DB1", "DB2", "DB3"], 
        "edges":  [("PP1", "RV1"), ("PP1", "RV2"), ("PP1", "RV3"), ("PP1", "DT1"), ("PP1", "DT2"), ("PP1", "DT3"),
         ("PP2", "RV1"), ("PP2", "RV2"), ("PP2", "RV3"), ("PP2", "DT1"), ("PP2", "DT2"), ("PP2", "DT3"),
         ("PP3", "RV1"), ("PP3", "RV2"), ("PP3", "RV3"), ("PP3", "DT1"), ("PP3", "DT2"), ("PP3", "DT3"),
         ("RV1", "RA1"), ("RV1", "RA2"), ("RV1", "RA3"),
         ("RV2", "RA1"), ("RV2", "RA2"), ("RV2", "RA3"),
         ("RV3", "RA1"), ("RV3", "RA2"), ("RV3", "RA3"),
         ("RA1", "DB1"), ("RA1", "DB2"), ("RA1", "DB3"),
         ("RA2", "DB1"), ("RA2", "DB2"), ("RA2", "DB3"),
         ("RA3", "DB1"), ("RA3", "DB2"), ("RA3", "DB3")],
    }
]

for graph in graphs:
    G = nx.DiGraph()
    G.add_nodes_from(graph["nodes"])
    G.add_edges_from(graph["edges"])
    uv_connectivities = []
    # Compute vertex connectivity
    for u in graph["nodes"]:
        for v in graph["nodes"]:
            if u == v:
                continue
            uv_connectivity = approx.local_node_connectivity(G, u, v)
            # print(f"Connectivity between {u} and {v} is {uv_connectivity}")
            uv_connectivities.append(uv_connectivity)

    total_connectivity = sum(uv_connectivities)
    print(f"{graph["name"]}: Total connectivity is {total_connectivity}")

    order = len(graph["nodes"])

    avg_node_connectivity = total_connectivity / binom(order, 2)
    print(f"{graph["name"]}: Average node connectivity is {avg_node_connectivity}")
