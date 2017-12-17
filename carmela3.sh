#!/bin/bash

# Funkcja tworzaca pasek postepu.

function progress_bar {
   let progress=(${1}*100/${2}*100)/100
   let finished=(${progress}*4)/10
   let left=40-$finished

   # Budowanie lancucha paska dlugosci postepu.

   fill=$(printf "%${finished}s")
   empty=$(printf "%${left}s")

   printf "\rOczekiwanie na uruchomienie Cassandry: [${fill// /#}${empty// /-}] ${progress} %%"
}

# Sprawdz czy uzytkownik jest rootem.

if [ $(id -u) -ne "0" ] # Jezeli nie jest zalogowany jako root.
then
   echo "[*] Carmela 3 to narzedzie do archiwizacji migawki Cassandry."

   echo "[!] Nie jestes zalogowany jako root!"

   exit 1 # Wyjscie z kodem bledu.
fi


while getopts :d:f:h argument; do
  case $argument in
      d)
	 # Katalog z keyspace'ami.

         keyspace_home=$OPTARG

         ;;
      f)
         # Nazwa archiwum.

         archive_name=$OPTARG

         ;;
      h)
         echo "[*] Carmela 3 to narzedzie do archiwizacji migawki Cassandry."

         echo "[*] Wywolanie: \"$0 -d katalog_z_keyspace'ami -f nazwa_archiwum (bez rozszerzenia)\"."

         exit 1

         ;;
      \?)
         echo "[!] Nieznana opcja. Wywolanie: \"$0 -d katalog_domowy_bazy_danych -f nazwa_archiwum (bez rozszerzenia)\"!"

         ;;
   esac
done

shift $((OPTIND-1)) # Powiedz getopts aby przeszedl do nastepnego argumentu.

# Sprawdz czy katalog domowy bazy danych istnieje.

if [ ! -d "$keyspace_home" ]
then
   echo "[!] Katalog bazy danych Cassandry \"$keyspace_home\" nie istnieje!"

   exit 1
fi

# Sprawdz czy Cassandra jest uruchomiona.

nodetool status > /dev/null

if [ $? -ne 0 ]
then
   read -r -p "[?] Czy chcesz wlaczyc Cassandre (pozostanie wlaczona po zakonczeniu dzialania programu)? Odpowiedz \"t\" lub \"n\": " response

   case $response in
      t)
         service cassandra start > /dev/null # Wlacz Cassandre.

         # Oczekiwanie na uruchomienie Cassandry.

         start=1
         end=60

         for number in $(seq ${start} ${end})
         do
            sleep 1 # Uspij na 1 sekunde.

            progress_bar ${number} ${end}
         done

         ;;
      *)
         echo "[!] Cassandra musi byc wlaczona aby zrobic zapasowa!"

         exit 1

         ;;
   esac
fi

# Wykonujemy migawke wszystkich przestrzeni.

snapshot_no=$(nodetool snapshot | awk 'NR==2' | awk '{print $NF}')
current_directory=${PWD}

mkdir $archive_name

archive_absolute_path=$(cd "$(dirname $archive_name)"; pwd)/$(basename $archive_name) # Zapisujemy sciezke bezwzgledna do katalogu archiwum.

for directory_keyspace in $keyspace_home/*
do
   directory_keyspace=${directory_keyspace%*/}
   keyspace=${directory_keyspace##*/}

   # Pomin przestrzenie systemowe.

   if [ "$keyspace" != "system" ] && [ "$keyspace" != "system_auth" ] && [ "$keyspace" != "system_distributed" ] && [ "$keyspace" != "system_schema" ] && [ "$keyspace" != "system_traces" ]
   then
      echo "[*] PRZESTRZEN: $keyspace"

      # Przejdz po wszystkich tabelach z przestrzeni.

      table_directories=`ls -t $keyspace_home/$keyspace/` # Wyswietl wszystkie katalogi tabel dla danej przestrzeni poczawszy od najmlodszych.
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

            echo "[*] Tabela: \"$table_name\" (katalog: \"$table_directory\")."

            # Wykonaj dzialania na tabeli (przywracanie kopii zapasowej).

            # Odnajdz katalog z numerem migawki.

            if [ ! -d "$keyspace_home/$keyspace/$table_directory/snapshots/$snapshot_no" ]
            then
               echo "[*] Katalog \"$keyspace_home/$keyspace/$table_directory/snapshots/$snapshot_no\" z migawka nie istnieje. Sprawdzam inne mozliwosci."

               if [ ! -d "$keyspace_home/$keyspace/$table_directory/snapshots/$snapshot_no-$table_name" ]
               then
                  echo "[!] Dla tabeli \"$table_name\" w przestrzeni \"$keyspace\" nie znaleziono katalogu z podanym numerem migawki!"

                  exit 1
               else
                  snapshot_directory="$keyspace_home/$keyspace/$table_directory/snapshots/$snapshot_no-$table_name"
               fi
            else
               snapshot_directory="$keyspace_home/$keyspace/$table_directory/snapshots/$snapshot_no"
            fi

            # Archiwizacja danych.

            echo "[*] Archiwizacja przestrzeni tabeli \"$table_name\" w przestrzeni \"$keyspace\"."

            mkdir -p $archive_absolute_path/$keyspace/$table_name

	    # Sprawdz czy w katalogu z migawka sa pliki o rozszerzeniu "db".

            count_db_files=(`find $snapshot_directory -maxdepth 1 -name "*.db"`)

            if [ ${#count_db_files[@]} -gt 0 ] # Jezeli sa tam jakies pliki o rozszerzeniu "db".
            then
               cp $snapshot_directory/*.db $archive_absolute_path/$keyspace/$table_name/
            fi

            cd $archive_absolute_path

            tar -jcvf $current_directory/$archive_name.tar.bz2 * > /dev/null
         fi
      done
   fi

done

rm -fr $archive_absolute_path