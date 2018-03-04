CREATE DATABASE  IF NOT EXISTS `rm` /*!40100 DEFAULT CHARACTER SET utf8 */;
USE `rm`;
-- MySQL dump 10.13  Distrib 5.6.13, for Win32 (x86)
--
-- Host: localhost    Database: rm
-- ------------------------------------------------------
-- Server version	5.6.16

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `event_requirement`
--

DROP TABLE IF EXISTS `event_requirement`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `event_requirement` (
  `eventRequirementID` bigint(20) NOT NULL AUTO_INCREMENT,
  `eventRequirementType` varchar(4) DEFAULT NULL,
  `eventRequirementNumber` bigint(20) DEFAULT NULL,
  `eventID` bigint(20) DEFAULT NULL,
  `audCreateTimeStamp` timestamp NULL DEFAULT NULL,
  `audCreateUserName` varchar(45) DEFAULT NULL,
  `audUpdateTimeStamp` timestamp NULL DEFAULT NULL,
  `audUpdateUserName` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`eventRequirementID`),
  KEY `FK_EventRequirementEvent_idx` (`eventID`),
  CONSTRAINT `FK_Event_Requirement_Event` FOREIGN KEY (`eventID`) REFERENCES `event` (`eventID`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=128 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `event_requirement`
--

LOCK TABLES `event_requirement` WRITE;
/*!40000 ALTER TABLE `event_requirement` DISABLE KEYS */;
INSERT INTO `event_requirement` VALUES (119,'Req',10,4764,'2014-03-19 21:36:13','rmSVNCommentParser',NULL,NULL),(120,'Req',11,4764,'2014-03-19 21:36:13','rmSVNCommentParser',NULL,NULL),(121,'Req',12,4764,'2014-03-19 21:36:13','rmSVNCommentParser',NULL,NULL),(122,'Req',13,4764,'2014-03-19 21:36:13','rmSVNCommentParser',NULL,NULL),(123,'Req',15,4764,'2014-03-19 21:36:13','rmSVNCommentParser',NULL,NULL),(124,'Def',20,4764,'2014-03-19 21:36:13','rmSVNCommentParser',NULL,NULL),(125,'Def',21,4764,'2014-03-19 21:36:13','rmSVNCommentParser',NULL,NULL),(126,'Def',22,4764,'2014-03-19 21:36:13','rmSVNCommentParser',NULL,NULL),(127,'Def',29,4764,'2014-03-19 21:36:13','rmSVNCommentParser',NULL,NULL);
/*!40000 ALTER TABLE `event_requirement` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2014-03-20  9:56:24
