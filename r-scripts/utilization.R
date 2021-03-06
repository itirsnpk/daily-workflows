#Attaches packages the script needs to run
suppressWarnings(suppressMessages(require(reshape)))
suppressWarnings(suppressMessages(require(dplyr)))

# Reads in files
AR      <-read.csv(paste("tmp/acosta-ramon", ".csv", sep=""),stringsAsFactors=FALSE)
cam     <-read.csv(paste("tmp/camcare", ".csv", sep=""),stringsAsFactors=FALSE)
Amb     <-read.csv(paste("tmp/cooper-ambulatory", ".csv", sep=""),stringsAsFactors=FALSE)
Fam     <-read.csv(paste("tmp/cooper-family-med", ".csv", sep=""),stringsAsFactors=FALSE)
Phys    <-read.csv(paste("tmp/cooper-physicians", ".csv", sep=""),stringsAsFactors=FALSE)
fairview<-read.csv(paste("tmp/fairview", ".csv", sep=""),stringsAsFactors=FALSE)
kylewill<-read.csv(paste("tmp/kyle-will", ".csv", sep=""),stringsAsFactors=FALSE)
Lourdes <-read.csv(paste("tmp/lourdes", ".csv", sep=""), stringsAsFactors=FALSE)
phope   <-read.csv(paste("tmp/project-hope", ".csv", sep=""),stringsAsFactors=FALSE)
reliance<-read.csv(paste("tmp/reliance", ".csv", sep=""),stringsAsFactors=FALSE)
luke    <-read.csv(paste("tmp/st-luke", ".csv", sep=""),stringsAsFactors=FALSE)
uhi     <-read.csv(paste("tmp/uhi", ".csv", sep=""),stringsAsFactors=FALSE)
#caplist <-read.csv(paste("tmp/caplist",  ".csv", sep=""), stringsAsFactors=FALSE)
#tvutils <-read.csv(paste("tmp/tvutils", ".csv", sep=""),stringsAsFactors=FALSE)

# Adds source column
AR       	$Report	<-	"Acosta Ramon"
cam     	$Report	<-	"CAMcare"
Amb     	$Report	<-	"Cooper Ambulatory"
Fam     	$Report	<-	"Cooper Family"
Phys    	$Report	<-	"Cooper Physicians"
uhi     	$Report	<-	"Cooper UHI"
fairview	$Report	<-	"Fairview"
kylewill	$Report	<-	"Kyle Will"
Lourdes 	$Report	<-	"Lourdes"
phope   	$Report	<-	"Project Hope"
reliance	$Report	<-	"Reliance"
luke    	$Report	<-	"St Lukes"

# Rename fields in UHI file
uhi <- reshape::rename(uhi, c(Last.Provider="Provider"))

# Adds extra fields with blank values to match column count
uhi$PCP.Name <- ""
uhi$Practice <- ""
uhi$Source <- ""

# Adds "NIC" to the uhi Subscriber ID if it's not already there 
uhi$Subscriber.ID <- ifelse(grepl("NIC", uhi$Subscriber.ID), uhi$Subscriber.ID, paste("NIC", uhi$Subscriber.ID, sep=""))

# Subsets camcare file to only include Horizon data
cam<-subset(cam, Source=="Horizon")

# Appends all files
aco <- rbind(AR,cam,Amb,Fam,Phys,uhi,fairview,kylewill,Lourdes,phope,reliance,luke)

# Sorts columns alphabetically
aco <- aco[,order(names(aco))]
uhi <- uhi[,order(names(uhi))]

# Appends remaining files
aco <-rbind(aco,uhi)

# Subtracts the Admit Date from Today's date and subsets those admitted in the last 21 days
aco2 <- subset(aco, (Sys.Date()- as.Date(aco$Admit.Date, format="%Y-%m-%d"))<21)

# Creates a CurrentlyAdmitted field with text from Admit.Date field
aco2$CurrentlyAdmitted <- gsub("\\(()\\)","\\1",  aco2$DischargeDate)

# Removes parenthetical values from DateAdmited field
aco2$DischargeDate <- gsub("\\(.*\\)","\\1", aco2$DischargeDate)

# Removes dates from CurrentlyAdmitted field
aco2$CurrentlyAdmitted <- ifelse(aco2$CurrentlyAdmitted == aco2$DischargeDate, "", aco2$CurrentlyAdmitted)

# Identifies the columns for the two lists to be exported
hieutils <- data.frame(aco2[,c(
  "Name",
  "Patient.ID",
  "Admit.Date",
  "Facility",
  "Patient.Class",
  "DischargeDate",
  "Provider",
  "Adm.Diagnoses",
  "Inp..6mo.",
  "ED..6mo.",
  "CurrentlyAdmitted",
  "Subscriber.ID",
  "Report"
)])

#Cleans date fields in the tvutils file by removing the time
#tvutils<-cSplit(tvutils, 1:2, sep="T", stripWhite=TRUE, type.convert=FALSE)
#tvutils$AdmitDate_2 <- NULL
#tvutils$DischargeDate_2 <- NULL
#tvutils$DischargeDate_1<-gsub("-0001-11-30", "" ,tvutils$DischargeDate_1)

#Renames date fields
#tvutils <- reshape::rename(tvutils, c(AdmitDate_1="AdmitDate"))
#tvutils <- reshape::rename(tvutils, c(DischargeDate_1="DischargeDate"))

#Replaces blanks with NAs in the tvutils DischargeDate field
#tvutils$DischargeDate[tvutils$DischargeDate==""]  <- NA 

#Replaces blanks with NA values in the hieutils DischargeDate field
hieutils$DischargeDate[hieutils$DischargeDate==""]  <- NA 

# Create ID field for utilizations in the import file
#hieutils$ID <- paste(hieutils$Patient.ID,hieutils$Admit.Date,hieutils$Facility,hieutils$Patient.Class,hieutils$DischargeDate, sep="-")

# Create ID field for utilizations in the trackvia file
#tvutils$ID <- paste(tvutils$HIEID,tvutils$AdmitDate,tvutils$Facility,tvutils$PatientClass,tvutils$DischargeDate, sep="-")

# Subset records that are not already in TrackVia
#acoUtilization <- hieutils[!hieutils$ID %in% tvutils$ID,]

# Step to circumvent the commented out lines
acoUtilization <- hieutils

# Renames fields to import
acoUtilization <- reshape::rename(acoUtilization, c(Patient.ID="HIEID"))
acoUtilization <- reshape::rename(acoUtilization, c(Admit.Date="AdmitDate"))
acoUtilization <- reshape::rename(acoUtilization, c(Patient.Class="PatientClass"))
acoUtilization <- reshape::rename(acoUtilization, c(Adm.Diagnoses="HistoricalDiagnosis"))
acoUtilization <- reshape::rename(acoUtilization, c(Inp..6mo.="Inp6mo"))
acoUtilization <- reshape::rename(acoUtilization, c(ED..6mo.="ED6mo"))

# Filters acoUtilization to find ED Standards
ed_standards <- filter(acoUtilization, ED6mo <= 4, acoUtilization$PatientClass == "E")

# Adds an "import" column to ED Standards subset
ed_standards$import <- "no"

# Records not in the ED subset are "yes" in the import column
acoUtilization <- suppressMessages(left_join(acoUtilization, ed_standards)) %>% mutate(import = ifelse(is.na(import), "yes", "no"))

# Gets ACO Utilizations where import is "yes" (and ED Standards are removed)
acoUtilization <- subset(acoUtilization, acoUtilization$import == "yes")

# Drops unused columns
acoUtilization$import <- NULL
acoUtilization$ID <- NULL

# Replaces NA with spaces
acoUtilization$DischargeDate <- as.character(acoUtilization$DischargeDate)
acoUtilization$DischargeDate[is.na(acoUtilization$DischargeDate)] <- ""

# Removes duplicate entries
acoUtilization<-unique(acoUtilization)

# Subsets records that have a corresponding SUBSCRIBER_ID in TrackVia
#acoUtilization<-subset(acoUtilization, (acoUtilization$Subscriber.ID %in% caplist$SUBSCRIBER_ID))

# Drops unused column
#acoUtilization$Subscriber.ID <- NULL

#Exports csv file
#write.csv(acoUtilization, (file=paste("ACO-Utilizations", ".csv", sep="")), row.names=FALSE)
write.csv(acoUtilization, stdout(), row.names=FALSE)
