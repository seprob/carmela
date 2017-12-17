#!/bin/bash

# Sprawdz czy uzytkownik jest rootem.

if [ "$(id -u)" -ne "0" ] # Jezeli nie jest zalogowany jako root.
then
   echo "[*] Carmela 4 to narzedzie do przywracania wszystkich keyspace'ow Cassandry z danego katalogu z kopia zapasowa."

   echo "[!] Nie jestes zalogowany jako root!"

   exit 1 # Wyjscie z kodem bledu.
fi

while getopts :d:b:c:h argument; do
  case $argument in
      d)
	 # Katalog z keyspace'ami.

         keyspace_home=$OPTARG

         ;;
      b)
         # Katalog z danymi kopii zapasowej (do odzyskania).

         data=$OPTARG

         ;;
      c)
         # Katalog "commitlog".

         commitlog_directory=$OPTARG

         ;;
      h)
         echo "[*] Carmela 4 to narzedzie do przywracania wszystkich keyspace'ow Cassandry z danego katalogu z kopia zapasowa."

         echo "[*] Wywolanie: \"$0 -d sciezka_do_katalogu_z_keyspace'ami -b sciezka_do_katalogu_z_danymi_kopii_zapasowej -c katalog_commitlog\"."

         exit 1

         ;;
      \?)
         echo "[!] Nieznana opcja. Wywolanie: \"$0 -d sciezka_do_katalogu_z_keyspace'ami -b sciezka_do_katalogu_z_danymi_kopii_zapasowej -c katalog_commitlog\"!"

         ;;
   esac
done

shift $((OPTIND-1)) # Powiedz getopts aby przeszedl do nastepnego argumentu.

# Sprawdz czy katalog domowy bazy danych istnieje.

if [ ! -d "$keyspace_home" ]
then
   echo "[!] Katalog z keyspace'ami Cassandry \"$keyspace_home\" nie istnieje!"

   exit 1
fi

# Sprawdz czy Cassandra jest uruchomiona.

if nodetool status > /dev/null 2>&1
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

if [ ! -d "$commitlog_directory" ]
then
   echo "[!] Katalog \"$commitlog_directory\" nie istnieje."

   exit 1
else
   rm -fr "${commitlog_directory:?}/"*
fi

# Przejdz po wszystkich przestrzeniach.

for directory_keyspace in $keyspace_home/*
do
   directory_keyspace=${directory_keyspace%*/}
   keyspace=${directory_keyspace##*/}

   # Pomin przestrzenie systemowe.

   if [ "$keyspace" != "system" ] && [ "$keyspace" != "system_auth" ] && [ "$keyspace" != "system_distributed" ] && [ "$keyspace" != "system_schema" ] && [ "$keyspace" != "system_traces" ]
   then
      echo "[*] PRZESTRZEN: $keyspace"

      # Przejdz po wszystkich tabelach z przestrzeni.

      table_directories=$(ls -t "$keyspace_home/$keyspace/") # Wyswietl wszystkie katalogi tabel dla danej przestrzeni poczawszy od najmlodszych.
      check_tables=() # Inicjalizacja tabeli przechowujacej nazwy tabel danej przestrzeni.

      for table_directory in $table_directories
      do
         # Wyodrebnij nazwe tabeli.

         table_name=$(echo "$table_directory" | awk -F'-' '{print $1}')

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
            check_tables+=("$table_name") # Jezeli nie ma to dodaj do listy.

            echo "[*] Tabela: $table_name (katalog: $table_directory)."

            # Wykonaj dzialania na tabeli (przywracanie kopii zapasowej).

            if [ ! -d "$data" ]
            then
               echo "[!] Katalog \"$data\" z danymi kopii zapasowej nie istnieje."

               exit 1
            fi

            # Przejdz po wszystkich tabelach w danej przestrzeni z kopii zapasowej.

            backup_table_directories=$(ls -t "$data/$keyspace/") # Wyswietl wszystkie katalogi tabel dla danej przestrzeni z kopii zapasowej poczawszy od najmlodszych.
            backup_check_tables=() # Inicjalizacja tabeli przechowujacej nazwy tabel danej przestrzeni z kopii zapasowej.

            for backup_table_directory in $backup_table_directories
            do
               # Wyodrebnij nazwe tabeli z kopii zapasowej.

               backup_table_name=$(echo "$backup_table_directory" | awk -F'-' '{print $1}')

               # Sprawdz czy nazwa tabeli z kopii zapasowej jest na liscie.

               backup_flag=0 # Poczatkowa wartosc nieprawdy czyli, ze nazwy tabeli z kopii zapasowej nie ma na liscie.

               if [ ${#backup_check_tables[@]} -ne 0 ] # Jezeli tablica nie jest pusta.
               then
                  for backup_iterator in "${backup_check_tables[@]}"
                  do
                     if [ "$backup_table_name" == "$backup_iterator" ] # Jezeli jest na liscie.
                     then
                        backup_flag=1 # Ustaw flage na prawde.
                     fi
                  done
               fi

               if [ $backup_flag -ne 1 ]
               then
                  backup_check_tables+=("$backup_table_name") # Jezeli nie ma to dodaj do listy.

                  if [ "$table_name" == "$backup_table_name" ]
                  then
                     echo "[*] Tabela kopii zapasowej: $backup_table_name (katalog: $backup_table_directory)."

                     # Docelowe przywracanie kopii zapasowej.

                     # Sprawdz czy w danym katalogu sa jakies pliki z rozszerzeniem "db".

                     mapfile -t count_db_files < <(find "$data/$keyspace/$backup_table_directory" -maxdepth 1 -name "*.db")

                     if [ ${#count_db_files[@]} -gt 0 ] # Jezeli sa tam jakies pliki o rozszerzeniu "db".
                     then
                        rm -fr "$keyspace_home/$keyspace/$table_directory"/*.db

                        cp "$data/$keyspace/$backup_table_directory"/*.db "$keyspace_home/$keyspace/$table_directory/"

                        chown cassandra:cassandra "$keyspace_home/$keyspace/$table_directory"/*
                     fi
                  fi
               fi
            done
         fi
      done
   fi
done