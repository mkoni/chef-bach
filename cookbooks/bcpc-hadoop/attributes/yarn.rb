default["bcpc"]["hadoop"]["yarn"]["log-aggregation_retain-seconds"] = 60*60*24*31
default["bcpc"]["hadoop"]["yarn"]["nodemanager"]["avail_memory"]["ratio"] = 0.5
default["bcpc"]["hadoop"]["yarn"]["nodemanager"]["avail_memory"]["size"] = nil
default["bcpc"]["hadoop"]["yarn"]["nodemanager"]["avail_vcpu"]["ratio"] = 0.5
default["bcpc"]["hadoop"]["yarn"]["nodemanager"]["avail_vcpu"]["count"] = nil
default["bcpc"]["hadoop"]["yarn"]["nodemanager"]["port"] = 45454
default["bcpc"]["hadoop"]["yarn"]["scheduler"]["class"] = "org.apache.hadoop.yarn.server.resourcemanager.scheduler.fair.FairScheduler"
default["bcpc"]["hadoop"]["yarn"]["scheduler"]["minimum-allocation-mb"] = 256
default['bcpc']['hadoop']['yarn']['historyserver']['heap']["size"] = 128
default['bcpc']['hadoop']['yarn']['historyserver']['heap']["ratio"] = 0
default["bcpc"]["hadoop"]["yarn"]["resourcemanager"]["port"] = 8032
default['bcpc']['hadoop']['yarn']['aux_services']['mapreduce_shuffle']['class'] = 'org.apache.hadoop.mapred.ShuffleHandler'
default['bcpc']['hadoop']['yarn']['opts']['jute_buffer'] = 6291456

