"""Prepare only the resource-refusal fixture, never canonical/golden evidence."""
import sys
from resource_fixture import prepare

prepare(sys.argv[1])
