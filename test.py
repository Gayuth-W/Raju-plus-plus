import sys
import time

print("Python script started...")
sys.stdout.flush()

with open("python_out.txt", "w") as f:
    f.write("Hello from Python!\n")

print("Python script completed successfully!")
sys.stdout.flush()
