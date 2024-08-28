#!/bin/bash
CLI_APP=/opt/ericsson/enmutils/bin/cli_app
eutrancellFDD_cell_list=/tmp/EutranCellFDD_cell_list.txt
node_list=/tmp/NetworkElement_node_list.txt
cells_per_node=$1

calculate_eutrancellfdd_cells_per_node(){
        ${CLI_APP} 'cmedit get * EutranCellFDD' > ${eutrancellFDD_cell_list}
        ${CLI_APP} 'cmedit get * NetworkElement -ne=ERBS' | awk -F "=" '{print $2}' > ${node_list}
        ${CLI_APP} 'cmedit get * NetworkElement -ne=RadioNode' | awk -F "=" '{print $2}'>> ${node_list}

        echo -e "Node Name \t\t\t\t # EutranCellFDD Cells" > ${cells_per_node};
        echo -e "========= \t\t\t\t =====================" >> ${cells_per_node};
        echo "" >> ${cells_per_node};

        for i in `cat ${node_list}`;
        do
            echo -en "$i \t" >> ${cells_per_node};
            grep -c $i ${eutrancellFDD_cell_list} >> ${cells_per_node};
        done
}


display_usage() {
        echo "Please give the path where you want the file stored"
        echo "e.g. /root/rvb/bin/fetch_eutrancellFDD_cells_per_node.sh /tmp/EutranCellFDD_cells_per_node.txt"
        echo -e "\nUsage:\n$0 [arguments] \n"
        }


if [  $# -lt 1 ] || [ $1 == "-h" ]
        then
                display_usage
                exit 1
        fi

calculate_eutrancellfdd_cells_per_node
rm -rf ${eutrancellFDD_cell_list} ${node_list}
echo "Count of EutranCellFDD cells per ERBS & RadioNodes is available in file: " ${cells_per_node}