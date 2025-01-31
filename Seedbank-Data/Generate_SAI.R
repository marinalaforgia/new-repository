# Calculating Seed Accumulation index (Holzel & Otte)
# Note the first half of the code calculates SAI by pooling information across serp and nonserp sites; the second half the code repeats these 10 steps but does so by calculating SAI separately to Serp and nonserp sites

#1. Load Packages and Data
#2. Calculate Frequency above and belowground to prep for Index 1 calculation
#3. Calculate cumulative aboveground cover and total seeds for Index 2 calculation
#4. Calculate Relative abundance for new index calculation
#5. Calculate SAI index 1 
#6. Calculate SAI index 2
#7. Calculate mean SAI 
#8. Calculate Relative abundance SAI
#9. Calculate SAI per site
#10. Export SAIs to csv file

####
# 1. Load packages and files
####
library(plyr)
library(dplyr)
#setwd("~//Documents//UC Davis//02_McLaughlin_80Sites_Organized//Seedbank Data")
cover <- read.csv("~//Documents//UC-Davis//02_McLaughlin_80Sites_Organized//Data-Storage-Files/Core_Community_Data2015.csv")
sb.by.year <- read.csv("Core_Seedbank.csv")

#### 
# 2. Alter datasets for Index 1
####

#remove abiotic from cover data
cover <- cover[which(!cover$Species_Name=="Bare"&!cover$Species_Name=="Rock"),]

# Cover frequency = (number of sites a species occurs in within a given year)
cover.freq <- ddply(cover, c("Year", "Species_Name"), summarize, freq.AB = length(unique(Site))) 
cover.freq <- cover.freq[which(cover.freq$Year == 2012 | cover.freq$Year == 2014),] # extract years in which we have seedbank data

# Seedbank frequency (number of sites a species occurs in within a given year)
sb.freq <- ddply(sb.by.year, c("Species_Name","Year"), summarize, freq.SB = length(unique(site)))

# Merge into one file
freq <- merge(cover.freq, sb.freq, by = c("Species_Name", "Year"), all = T)
freq <- reshape(freq, v.names = c("freq.AB","freq.SB"), idvar = "Species_Name", timevar = "Year", direction = "wide")
freq[is.na(freq)] <- 0 # is the absence of a species for the seedbank sampling indicative of sampling error, thus the index should be calculated using only the year in which it appears, or is it indicative of absence from the seedbank so the measure should be averaged with 0? I lean towards the first one.

####  
# 3. Prep dataset for Index 2
####
# in the paper they dont have it as relative abundance in the seedbank, they have total abundance in the seedbank and cumulative cover of each species

#Cumulative cover (which might not necessarily make sense to avg cover across all 80 sites because of serpentine/nonserpentine)
cover.post06<-na.omit(cover) # get rid of 2000-2006 when cover was not measured
Index2<-ddply(cover.post06, "Species_Name", summarize, cum.AB = sum(Cover)/length(unique(cover.post06$Year)))

#Total seeds in both years of sampling
SBquant <- ddply(sb.by.year, c("Species_Name","Year"), summarize, Tot.ab = sum(Count))

#Total seeds across both years of sampling
SB.total <- ddply(SBquant, "Species_Name", summarize, sum.SB = sum(Tot.ab))
 
#merge datasets
Index2<- merge(SB.total, Index2, by = "Species_Name", all = T)

####
# 4. Alter datasets for Relative abundance Index, not in proper SAI but is more intuitive
####
# Relative abundance in Cover
cover.post06<- ddply(cover.post06, c("Site","Year","Species_Name"), summarize, Cover = sum(Cover))
cover.post06 <- merge(cover.post06, ddply(cover.post06, c("Site","Year"), summarize, Tot.cov = sum(Cover)), by=c("Site","Year"), all.x =T)
cover.post06$RA <- cover.post06$Cover/cover.post06$Tot.cov*100
cover.RA <- ddply(cover.post06, "Species_Name", summarize, AB = mean(RA))

# Relative abundance in seedbank
RA.SB <- merge(sb.by.year, ddply(sb.by.year, c("site", "Year"), summarize, Tot.ab = sum(Count)), by=c("site", "Year"), all.x =T)
RA.SB$RA <- RA.SB$Count/RA.SB$Tot.ab*100
RA.SB <- ddply(RA.SB, "Species_Name", summarize, SB = mean(RA))

# Merge into one file
RA <- merge(cover.RA, RA.SB, by = "Species_Name", all = T)
RA[is.na(RA)]<-0

#####
# 5. Calculate SAI Index 1 (SBfreq / (SBfreq + ABfreq)) * 100 (SAI INDEX 1)
####
# Index 1 "relates the plot frequency of a certain species in above ground vegetation with its frequency in the soil seed bank"; this doesn't specify how this is calculated in relation to the various years

# Index 1: 2012
freq$SAI1.2012 <- (freq$freq.SB.2012 / (freq$freq.AB.2012 + freq$freq.SB.2012)) * 100

# Index 1: 2014
freq$SAI1.2014 <- (freq$freq.SB.2014 / (freq$freq.AB.2014 + freq$freq.SB.2014)) * 100

# Index 1 average
freq$SAI1 <- rowMeans(freq[,6:7])

#####
# 6. Calculate SAI Index 2 (SBquant / (SBquant + ABcover)) * 100
####
# Index 2: "Relates the cumulative cover of a certain species over all plots to the total number of seeds recorded in the seed bank over all plots in both years of sampling"
# "Cover was calculated as an average of three years" for us this would be the average cumulative cover across 9 years
Index2$SAI2 <- Index2$sum.SB / (Index2$sum.SB + Index2$cum.AB) * 100

####
# 7. OVERALL SAI = average(index 1, index 2)
####
SAI <- merge(freq[,c(1,8)],Index2[,c(1,4)],by="Species_Name")
SAI$SAI <- rowMeans(SAI[,2:3])

####
# 8. SAI using relative abundance belowground vs relative cover aboveground
####
RA$SAI3 <- RA$SB / (RA$SB + RA$AB) * 100
SAI <- merge(SAI,RA[,c(1,4)],by="Species_Name")

#remove bulbs and unknowns
NoID <- c("Unknown forb", "Unknown grass", "bulb", "grass 8", "grass 73", "Bromus sp.")
SAI <- SAI[which(!SAI$Species_Name%in%NoID),]
colnames(SAI)<- c("Species_Name","SAI_Index1","SAI_Index2","SAI","SAI_RelAb")

####
# 9. SAI per Site
###
SAIperSite <- merge(sb.by.year, SAI, by = "Species_Name")
SAIperSite <- SAIperSite[,c(2,3,1,4:10)]
SAIperSite <- SAIperSite[order(SAIperSite$site),]

####
# 10. Export Files
###
write.table(SAI,"SAI-by-species.csv",sep=",",row.names=F)
write.table(SAIperSite,"SAI-by-site.csv",sep=",",row.names=F)

#######
# Calculate SAI separately for serpentine/nonserpentine
###

#### 
# 2. Alter datasets for Index 1
####

# Merge Cover with soil type
cover <- merge(cover, unique(sb.by.year[,1:2]), by.x = "Site", by.y = "site", all = T)
# Cover frequency = (number of sites a species occurs in within a given year)
cover.freq <- ddply(cover, c("Year", "Species_Name","Serpentine"), summarize, freq.AB = length(unique(Site))) 
cover.freq <- cover.freq[which(cover.freq$Year == 2012 | cover.freq$Year == 2014),] # extract years in which we have seedbank data

# Seedbank frequency (number of sites a species occurs in within a given year)
sb.freq <- ddply(sb.by.year, c("Species_Name","Year","Serpentine"), summarize, freq.SB = length(unique(site)))

# Merge into one file
freq <- merge(cover.freq, sb.freq, by = c("Species_Name", "Year","Serpentine"), all = T)
freq <- reshape(freq, v.names = c("freq.AB","freq.SB"), idvar = c("Species_Name","Serpentine"), timevar = "Year", direction = "wide")
freq[is.na(freq)] <- 0 # is the absence of a species for the seedbank sampling indicative of sampling error, thus the index should be calculated using only the year in which it appears, or is it indicative of absence from the seedbank so the measure should be averaged with 0? I lean towards the first one.

####  
# 3. Prep dataset for Index 2
####
# in the paper they dont have it as relative abundance in the seedbank, they have total abundance in the seedbank and cumulative cover of each species

#Cumulative cover (which might not necessarily make sense to avg cover across all 80 sites because of serpentine/nonserpentine)
cover.post06<-na.omit(cover) # get rid of 2000-2006 when cover was not measured
Index2<-ddply(cover.post06, c("Species_Name","Serpentine"), summarize, cum.AB = sum(Cover)/length(unique(cover.post06$Year)))

#Total seeds in both years of sampling
SBquant <- ddply(sb.by.year, c("Species_Name","Year","Serpentine"), summarize, Tot.ab = sum(Count))

#Total seeds across both years of sampling
SB.total <- ddply(SBquant, c("Species_Name","Serpentine"), summarize, sum.SB = sum(Tot.ab))

#merge datasets
Index2<- merge(SB.total, Index2, by = c("Species_Name","Serpentine"), all = T)

####
# 4. Alter datasets for Relative abundance Index, not in proper SAI but is more intuitive
####
# Relative abundance in Cover
cover.post06<- ddply(cover.post06, c("Site","Year","Species_Name","Serpentine"), summarize, Cover = sum(Cover))
cover.post06 <- merge(cover.post06, ddply(cover.post06, c("Site","Year","Serpentine"), summarize, Tot.cov = sum(Cover)), by=c("Site","Year","Serpentine"), all.x =T)
cover.post06$RA <- cover.post06$Cover/cover.post06$Tot.cov*100
cover.RA <- ddply(cover.post06, c("Species_Name","Serpentine"), summarize, AB = mean(RA))

# Relative abundance in seedbank
RA.SB <- merge(sb.by.year, ddply(sb.by.year, c("site", "Year","Serpentine"), summarize, Tot.ab = sum(Count)), by=c("site", "Year", "Serpentine"), all.x =T)
RA.SB$RA <- RA.SB$Count/RA.SB$Tot.ab*100
RA.SB <- ddply(RA.SB, c("Species_Name","Serpentine"), summarize, SB = mean(RA))

# Merge into one file
RA <- merge(cover.RA, RA.SB, by = c("Species_Name","Serpentine"), all = T)
RA[is.na(RA)]<-0

#####
# 5. Calculate SAI Index 1 (SBfreq / (SBfreq + ABfreq)) * 100 (SAI INDEX 1)
####
# Index 1 "relates the plot frequency of a certain species in above ground vegetation with its frequency in the soil seed bank"; this doesn't specify how this is calculated in relation to the various years

# Index 1: 2012
freq$SAI1.2012 <- (freq$freq.SB.2012 / (freq$freq.AB.2012 + freq$freq.SB.2012)) * 100

# Index 1: 2014
freq$SAI1.2014 <- (freq$freq.SB.2014 / (freq$freq.AB.2014 + freq$freq.SB.2014)) * 100

# Index 1 average
freq$SAI1 <- rowMeans(freq[,7:8])

#####
# 6. Calculate SAI Index 2 (SBquant / (SBquant + ABcover)) * 100
####
# Index 2: "Relates the cumulative cover of a certain species over all plots to the total number of seeds recorded in the seed bank over all plots in both years of sampling"
# "Cover was calculated as an average of three years" for us this would be the average cumulative cover across 9 years
Index2$SAI2 <- Index2$sum.SB / (Index2$sum.SB + Index2$cum.AB) * 100

####
# 7. OVERALL SAI = average(index 1, index 2)
####
SAI <- merge(freq[,c(1,2,9)],Index2[,c(1,2,5)],by=c("Species_Name","Serpentine"))
SAI$SAI <- rowMeans(SAI[,3:4])

####
# 8. SAI using relative abundance belowground vs relative cover aboveground
####
RA$SAI3 <- RA$SB / (RA$SB + RA$AB) * 100
SAI <- merge(SAI,RA[,c(1,2,5)],by=c("Species_Name","Serpentine"))

#remove bulbs and unknowns
NoID <- c("Unknown forb", "Unknown grass", "bulb", "grass 8", "grass 73", "Bromus sp.")
SAI <- SAI[which(!SAI$Species_Name%in%NoID),]
colnames(SAI)<- c("Species_Name","Serpentine","SAI_Index1","SAI_Index2","SAI","SAI_RelAb")

####
# 9. SAI per Site
###
SAIperSite <- merge(sb.by.year, SAI, by = c("Species_Name","Serpentine"))
SAIperSite <- SAIperSite[,c(3,2,5,1,4,6:10)]
SAIperSite <- SAIperSite[order(SAIperSite$site),]

####
# 10. Export Files
###
write.table(SAI,"SAI-by-species-S.csv",sep=",",row.names=F)
write.table(SAIperSite,"SAI-by-site-S.csv",sep=",",row.names=F)
