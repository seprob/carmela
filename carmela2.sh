#!/bin/bash

# Sprawdz czy uzytkownik jest rootem.

if [ $(id -u) -ne "0" ] # Jezeli nie jest zalogowany jako root.
then
   echo "[!] Nie jestes zalogowany jako root!"

   exit 1 # Wyjscie z kodem bledu.
fi

while getopts :d:s:h argument; do
  case $argument in
      d)
	 # Katalog domowy bazy danych.

         database_home=$OPTARG

         ;;
      s)
         # Numer migawki.

         snapshot_no=$OPTARG

         ;;
      h)
         echo "[*] Wywolanie: \"$0 -d katalog_domowy_bazy_danych -s numer_migawki\"."

         exit 1

         ;;
      \?)
         echo "[!] Nieznana opcja. Wywolanie: \"$0 -d katalog_domowy_bazy_danych -s numer_migawki\"!"

         ;;
   esac
done

shift $((OPTIND-1)) # Powiedz getopts aby przeszedl do nastepnego argumentu.

# Sprawdz czy katalog domowy bazy danych istnieje.

if [ ! -d "$database_home" ]
then
   echo "[!] Katalog bazy danych Cassandry \"$database_home\" nie istnieje!"

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

# Przejdz po wszystkich przestrzeniach.

for directory_keyspace in $database_home/data/*
do
   directory_keyspace=${directory_keyspace%*/}
   keyspace=${directory_keyspace##*/}

   # Pomin przestrzenie systemowe.

   if [ "$keyspace" != "system" ] && [ "$keyspace" != "system_auth" ] && [ "$keyspace" != "system_distributed" ] && [ "$keyspace" != "system_schema" ] && [ "$keyspace" != "system_traces" ]
   then
      echo "PRZESTRZEN: $keyspace"

      # Przejdz po wszystkich tabelach z przestrzeni.

      table_directories=`ls -t $database_home/data/$keyspace/` # Wyswietl wszystkie katalogi tabel dla danej przestrzeni poczawszy od najmlodszych.
      check_tables=() # Inicjalizacja tabeli przechowujacej nazwy tabel danej przestrzeni.

      for table_directory in $table_directories
      do
         # Wyodrebnij nazwe tabeli.

         table_name=`echo $table_directory | awk -F'-' '{print $1}'`

         # Sprawdz czy nazwa tabeli jest na liscie.

         flag=0 # Poczatkowa wartosc nieprawdy czyli, ze nazwy tabeli nie ma na liscie.

         if [ ${#check_tables[@]} -ne 0 ] # Jezeli tablica nie jest pusta.
         then
            for iterator in "${check_tables[@]}"
            do
               if [ "$table_name" == "$iterator" ] # Jezeli jest na liscie.
               then
                  flag=1 # Ustaw flage na prawde.
               fi
            done
         fi

         # Jezeli tabeli nie ma na liscie.

         if [ $flag -ne 1 ]
         then
            check_tables+=($table_name) # Jezeli nie ma to dodaj do listy.

            echo "Tabela: $table_name (katalog: $table_directory)."

            # Wykonaj dzialania na tabeli (przywracanie kopii zapasowej).

            # Odnajdz katalog z numerem migawki.

            if [ ! -d "$database_home/data/$keyspace/$table_directory/snapshots/$snapshot_no" ]
            then
               echo "[*] Katalog \"$database_home/data/$keyspace/$table_directory/snapshots/$snapshot_no\" z migawka nie istnieje. Sprawdzam inne mozliwosci."

               if [ ! -d "$database_home/data/$keyspace/$table_directory/snapshots/$snapshot_no-$table_name" ]
               then
                  echo "[!] Dla tabeli \"$table_name\" w przestrzeni \"$keyspace\" nie znaleziono katalogu z podanym numerem migawki!"

                  exit 1
               else
                  snapshot_directory="$database_home/data/$keyspace/$table_directory/snapshots/$snapshot_no-$table_name"
               fi
            else
               snapshot_directory="$database_home/data/$keyspace/$table_directory/snapshots/$snapshot_no"
            fi

            # Sprawdz czy w katalogu z migawka sa pliki o rozszerzeniu "db".

            count_db_files=(`find $snapshot_directory -maxdepth 1 -name "*.db"`)

            if [ ${#count_db_files[@]} -gt 0 ] # Jezeli sa tam jakies pliki o rozszerzeniu "db".
            then
               # Przywracamy kopie zapasowa.

               rm -fr $database_home/data/$keyspace/$table_directory/*.db

               cp $snapshot_directory/*.db $database_home/data/$keyspace/$table_directory/

               chown cassandra:cassandra $database_home/data/$keyspace/$table_directory/*
            fi
         fi
      done
   fi
done