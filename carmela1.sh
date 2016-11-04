#!/bin/bash

# Sprawdz czy uzytkownik jest rootem.

if [ $(id -u) -ne "0" ] # Jezeli nie jest zalogowany jako root.
then
   echo "[!] Nie jestes zalogowany jako root!"

   exit 1 # Wyjscie z kodem bledu.
fi

while getopts :k:t:d:b:h argument; do
   case $argument in
      k)
         # Nazwa przestrzeni.

         keyspace=$OPTARG

         ;;
      t)
         # Nazwa tabeli.

         table=$OPTARG

         ;;
      d)
         # Katalog z danymi kopii zapasowej (do odzyskania).

         data=$OPTARG

         ;;
      b)
         # Katalog domowy bazy danych.

         database_home=$OPTARG

         ;;
      h)
         echo "[*] Wywolanie: \"$0 -k nazwa_przestrzeni -t nazwa_tabeli -d sciezka_do_katalogu_z_danymi -b katalog_domowy_bazy_danych\"."

         exit 1

         ;;
      \?)
         echo "[!] Nieznana opcja (wywolanie: \"$0 -k nazwa_przestrzeni -t nazwa_tabeli -d sciezka_do_katalogu_z_danymi -b katalog_domowy_bazy_danych\")!"

         ;;
   esac
done

shift $((OPTIND-1)) # Powiedz getopts aby przeszedl do nastepnego argumentu.

# Sprawdz czy katalog domowy bazy danych istnieje.

if [ ! -d "$database_home" ]
then
   echo "[!] Katalog bazy danych Cassandry \"$database_home\" nie istnieje."

   exit 1
fi

# Sprawdz czy podana przestrzen istnieje.

ls $database_home/data | grep -w $keyspace > /dev/null

if [ $? -ne 0 ]
then
   echo "[!] Podana przestrzen nie istnieje!"

   exit 1
fi

# Sprawdz czy podana tabela istnieje (pobierz ostatni stworzony katalog z przedroskiem nazwy tabeli).

table_directory=`ls -t $database_home/data/$keyspace | grep ^$table- | head -1`

if [ $? -ne 0 ]
then
   echo "[!] Podana tabela nie istnieje!"

   exit 1
fi

# Sprawdz czy podana sciezka z danymi kopii zapasowych istnieje.

if [ ! -d "$data" ]
then
   echo "[!] Katalog \"$data\" z danymi kopii zapasowej nie istnieje!"

   exit 1
fi

# Sprawdz czy Cassandra jest uruchomiona.

status=`service cassandra status`

if [ "$status" == " * Cassandra is running" ]
then
   read -r -p "[?] Czy chcesz zatrzymac Cassandre (pozostanie wylaczona po zakonczeniu dzialania program)? Odpowiedz \"t\" lub \"n\": " response

   case $response in
      t)
         service cassandra stop > /dev/null # Zatrzymaj Cassandre.
         ;;
      *)
         echo "[!] Cassandra musi byc wylaczona aby wgrac kopie zapasowa!"

         exit 1
         ;;
   esac
fi

# Usun "commitlog".

if [ ! -d "$database_home/commitlog" ]
then
   echo "[*] Katalog \"$database_home/commitlog\" nie istnieje. Sprawdzam w katalogu wyzej."

   upper_directory=`cd $database_home; cd ..; pwd`

   # Sprawdz czy katalog wyzej to "cassandra".

   cd $database_home; cd ..

   current_directory=${PWD##*/} # Pobierz nazwe aktualnego katalogu (bez pelnej sciezki).

   if [ "$current_directory" = "cassandra" ]
   then
      if [ ! -d "$upper_directory/commitlog" ]
      then
         echo "[!] Katalog \"$upper_directory/commitlog\" nie istnieje!"

         exit 1
      else
         rm -fr $upper_directory/commitlog
      fi
   fi
else
   rm -fr $database_home/commitlog/*
fi

# Sprawdz czy w katalogu z migawka sa pliki o rozszerzeniu "db".

count_db_files=(`find $data -maxdepth 1 -name "*.db"`)

if [ ${#count_db_files[@]} -gt 0 ] # Jezeli sa tam jakies pliki o rozszerzeniu "db".
then
   # Przywracamy kopie zapasowa.

   rm -fr $database_home/data/$keyspace/$table_directory/*.db

   cp $data/*.db $database_home/data/$keyspace/$table_directory/

   chown cassandra:cassandra $database_home/data/$keyspace/$table_directory/*
fi