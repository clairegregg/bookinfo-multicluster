import networkx as nx
import numpy

graphs = [
    {
        "name": "Single cluster", 
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
    avg_node_connectivity = nx.connectivity.connectivity.average_node_connectivity(G)
    print(f"{graph["name"]}: Average node connectivity is {avg_node_connectivity}")

    # Avg shortest path length
    avg_shortest_path = nx.average_shortest_path_length(G)
    print(f"{graph["name"]}: Average shortest path length is {avg_shortest_path}")

    # Network criticality
    # Copied from https://github.com/tomwelsh/embryonic-cloud/blob/1904591c20f3615f7f73dd91406ed07cd8b54b93/3%20-%20Embyronic%20Experiments/timeline.py#L143-L156
    a=2/(len(G.nodes())-1)
    lm=nx.linalg.laplacianmatrix.directed_laplacian_matrix(G)
    l=numpy.linalg.pinv(lm)
    network_criticality=a*numpy.trace(l)  #network criticality
    n=network_criticality/(len(G.nodes())*(len(G.nodes())-1))
    print(f"{graph["name"]}: Normalised network criticality is {n}")

    # Effective graph resistance
    # Copied from https://github.com/tomwelsh/embryonic-cloud/blob/1904591c20f3615f7f73dd91406ed07cd8b54b93/3%20-%20Embyronic%20Experiments/timeline.py#L158-L171
    egr=0
    g=G.to_undirected()
    ev=nx.linalg.spectrum.laplacian_spectrum(g)
    egr=0
    i=0

    for x in g.nodes():
        for y in g.nodes():
            if x != y:
                egr=egr+(nx.algorithms.distance_measures.resistance_distance(g,x,y))
    c=(len(g.nodes())-1)/egr

    print(f"{graph["name"]}: Normalised effective graph conductance is {c}")

