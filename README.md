# Simulation Research

This repository contains various crowd simulation shaders simulations using compute shaders in [Godot 4.4.1](https://godotengine.org/download/archive/4.4.1-stable/). The program itself is not expected to be compiled, and instead runs direclty in Godot through the use of a custom plugin.

Features:
 * A GUI for defining parameters in the Godot Engine itself
 * A generic short-range constraint that pushes agents away based on overlap
 * Implementation of the following long-range distance constraint: https://web.cs.ucla.edu/~dt/theses/weiss-thesis.pdf
 * Settings for laying out collidable walls
 * Allow agents areas to move towards set areas in sequence (for the purpose of simulating moving with intent)
 * Run multiple iteraitions of the constraints per-frame for more accurate simulation (useful in high-density simulations)
