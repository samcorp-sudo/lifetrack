

public class nestloop {
    public static void main(String[] args) {
        int o = 1;
        int i = 1;
        int in = 1;

        for (o = 1; o <= 4; o++) {
            for (i = 6; i >= o; i--) {
                System.out.print(" ");
            }
                for (in = 1; in <= o; in++) {
                    System.out.print("* ");
                }
            

            System.out.println();
        }
    }
}