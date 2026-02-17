
import math

def calculate_interest(R, r, T, delta):
    """
    R: Annual revenue (USD)
    r: Supply APY (decimal)
    T: Time horizon (years)
    delta: Minting interval (years)
    """
    return (R * r * T * (T - delta)) / 2

def calculate_cost(R, r, T, delta1, delta2):
    return (R * r * T * (delta1 - delta2)) / 2

def calculate_optimal_delta(G, R, r):
    return math.sqrt((2 * G) / (R * r))

# User's Example Values
R_example = 20_718_135.99
r_example = 0.0194
T_example = 3
delta1 = 1.0
delta2 = 0.25

# Verify Cost Calculation
cost = calculate_cost(R_example, r_example, T_example, delta1, delta2)
print(f"Cost(1, 0.25): ${cost:,.2f}")
print(f"User's Value: $452,173.23")

# Check Discrete Summation (Simulation)
# Simulates minting every delta and accruing interest on minted amount
def simulate_interest(R, r, T, delta):
    steps = int(round(T / delta))
    total_interest = 0
    minted_amount = 0
    
    # At each step i*delta, we mint R*delta
    # That minted amount earns interest for remaining time? 
    # Or does it compound? User formula implies simple interest on the principal.
    # Formula: sum( R*delta * r * (T - i*delta) )
    
    amount_per_mint = R * delta
    for i in range(1, steps + 1):
        t_mint = i * delta
        time_remaining = T - t_mint
        interest_for_chunk = amount_per_mint * r * time_remaining
        total_interest += interest_for_chunk
        
    return total_interest

sim_interest = simulate_interest(R_example, r_example, T_example, delta2)
formula_interest = calculate_interest(R_example, r_example, T_example, delta2)

print(f"\nSimulated Interest (delta={delta2}): ${sim_interest:,.2f}")
print(f"Formula Interest   (delta={delta2}): ${formula_interest:,.2f}")

# Verify Generalized Form
# Delta* = sqrt( 2 * G_eth * P_eth / (R_asset * P_asset * r) )
#        = sqrt( (2 * G_eth / (R_asset * r)) * (P_eth / P_asset) )

