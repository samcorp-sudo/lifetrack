import java.text.DateFormat;
import java.util.Date;

public class code {
    public static void main(String[] args) {

        var time = new Date(11,7,2026);
        int dueDate = new Date(11,7,2026);

        if (time.Now >= dueDate) {
            System.out.print("Pay me now");
        }
    }
}
