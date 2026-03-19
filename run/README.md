# `/run`

The `/.run` directory is used for scripts for the care and feeding of motherbox itself.

```
./run/setup.sh         # Initial setup script for motherbox
./run/maintain.sh      # Lots of the managed packages need periodic maintenance; bundle them into one
./run/sync.sh          # Ensures that motherbox scripts are sym-linked to a consistent location across machines
./run/test.sh          # Runs tests just in case I wrote some
```
