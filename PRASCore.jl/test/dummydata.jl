module DummyData

using Dates
using TimeZones

const tz = tz"UTC"

nsamples = 100
alpha = 0.95

resourcenames = ["A", "B", "C"]
nresources = length(resourcenames)
testresource_idx = 2
testresource = resourcenames[testresource_idx]
notaresource = "NotAResource"

interfacenames = ["A"=>"B", "B"=>"C", "A"=>"C"]
ninterfaces = length(interfacenames)
testinterface_idx = 3
testinterface = interfacenames[testinterface_idx]
notaninterface = "X"=>"Y"

periods = ZonedDateTime(2012,4,1,0,tz):Hour(1):ZonedDateTime(2012,4,7,23,tz)
nperiods = length(periods)
resource_vals = rand(0:999, nresources, nperiods)
testperiod_idx = 29
testperiod = periods[testperiod_idx]
notaperiod = ZonedDateTime(2010,1,1,0,tz)

d = rand(0:999, nresources, nperiods, nsamples)

d1 = rand()
d1_resource = rand(nresources)
d1_period = rand(nperiods)
d1_resourceperiod = rand(nresources, nperiods)
d1_sample = rand(nsamples) * 999
d1_resourcesample = rand(nresources, nsamples) * 999

d2 = rand()
d2_resource = rand(nresources)
d2_period = rand(nperiods)
d2_resourceperiod = rand(nresources, nperiods)

d3 = rand()
d3_resource = rand(nresources)
d3_period = rand(nperiods)
d3_resourceperiod = rand(nresources, nperiods)

d4 = rand()
d4_resource = rand(nresources)
d4_period = rand(nperiods)
d4_resourceperiod = rand(nresources, nperiods)

end

import .DummyData
const DD = DummyData
